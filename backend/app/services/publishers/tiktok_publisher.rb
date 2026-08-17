module Publishers
  # TikTok adapter.
  #
  # Auth: TikTok Login Kit, OAuth 2.0, credentials in TIKTOK_CLIENT_KEY /
  # TIKTOK_CLIENT_SECRET. Access tokens last a day and do carry a refresh token,
  # so this adapter implements refresh_token!.
  #
  # Publishing goes through the Content Posting API's *inbox* endpoint, which the
  # `video.upload` scope grants. That sends the video to the creator's TikTok
  # drafts and notifies them to finish the post in the app. Posting straight to
  # the feed is a different endpoint gated on `video.publish`, which requires
  # passing TikTok's app audit, so it is deliberately not used here.
  #
  # Content constraint: no text-only post. Post#media_urls or an uploaded video
  # must carry the file, and Post#content becomes the caption the creator sees
  # pre-filled.
  class TiktokPublisher < Base
    INIT_URL = "https://open.tiktokapis.com/v2/post/publish/inbox/video/init/".freeze
    STATUS_URL = "https://open.tiktokapis.com/v2/post/publish/status/fetch/".freeze
    TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/".freeze

    # Staying at or below TikTok's 64 MB single-chunk ceiling means every upload
    # is one PUT; past it the API requires sequenced multi-chunk transfers.
    DEFAULT_MAX_VIDEO_BYTES = 64 * 1024 * 1024

    # Inbox upload is async after the PUT. SEND_TO_USER_INBOX is the success
    # state; returning earlier would tell the user it worked when TikTok later
    # rejects the file.
    INBOX_READY_STATUSES = %w[SEND_TO_USER_INBOX PUBLISH_COMPLETE].freeze
    IN_FLIGHT_STATUSES = %w[PROCESSING_UPLOAD PROCESSING_DOWNLOAD PROCESSING].freeze
    STATUS_ATTEMPTS = 20
    STATUS_WAIT_SECONDS = 2

    FAIL_REASON_MESSAGES = {
      "file_format_check_failed" =>
        "TikTok rejected the file format. Use an MP4, MOV or WebM that is 23-60 FPS " \
        "and at least 360 pixels on each side.",
      "duration_check_failed" =>
        "TikTok rejected the video length. It must be between 3 seconds and 10 minutes.",
      "frame_rate_check_failed" =>
        "TikTok rejected the frame rate. Use a video between 23 and 60 FPS.",
      "picture_size_check_failed" =>
        "TikTok rejected the resolution. Each side must be at least 360 pixels.",
      "internal" => "TikTok could not process the video. Try again in a minute.",
      "auth_removed" => "The TikTok account was disconnected while the video was uploading. Reconnect and try again.",
      "spam_risk_too_many_posts" =>
        "This TikTok account has posted too many times in 24 hours via the API.",
      "spam_risk_user_banned_from_posting" =>
        "TikTok has blocked this account from creating new posts.",
      "spam_risk_text" => "TikTok rejected the caption.",
      "spam_risk" => "TikTok rejected this upload as risky."
    }.freeze

    # TikTok reports problems with a stable error code. These are the ones a user
    # can act on, phrased for the person who will read them in the app.
    ERROR_MESSAGES = {
      "access_token_invalid" =>
        "Your TikTok connection has expired. Reconnect the account and try again.",
      "scope_not_authorized" =>
        "This TikTok connection is missing permission to upload videos. Reconnect the account.",
      "spam_risk_too_many_pending_share" =>
        "TikTok allows only 5 uploads awaiting your review per day. Finish or discard the drafts " \
        "already waiting in your TikTok inbox, then try again.",
      "spam_risk_user_banned_from_posting" =>
        "TikTok has blocked this account from creating new posts.",
      "rate_limit_exceeded" =>
        "TikTok is rate limiting this account. Try again in a minute.",
      "url_ownership_unverified" =>
        "TikTok rejected the video source.",
      "invalid_param" =>
        "TikTok rejected the video. Check that it is between 3 seconds and 10 minutes long, " \
        "23-60 FPS, and at least 360 pixels on each side."
    }.freeze

    # Codes that mean the stored credentials are the problem rather than the post.
    CREDENTIAL_ERROR_CODES = %w[access_token_invalid scope_not_authorized].freeze

    # Codes worth another attempt later; everything else is a firm rejection.
    RETRYABLE_ERROR_CODES = %w[rate_limit_exceeded internal internal_error].freeze

    def self.implemented?
      true
    end

    # TikTok cannot accept a text-only post, so callers must supply media before
    # they bother queuing anything.
    def self.requires_media?
      true
    end

    protected

    # Returns the publish_id, which is the only handle TikTok gives out for an
    # inbox upload. A real post id exists only after the creator publishes the
    # draft themselves.
    def perform_publish(post, _post_target)
      with_video(post) do |media|
        target = initialize_upload(media)

        begin
          media.file.rewind if media.file.respond_to?(:rewind)

          Http.put_binary(
            target.fetch("upload_url"),
            media.file,
            content_type: media.content_type,
            size: media.size
          )
        rescue Http::Error => e
          raise PublishError.new(
            "TikTok did not accept the video upload: #{e.message}",
            platform: self.class.platform_name,
            retryable: e.retryable?
          )
        end

        wait_until_in_inbox(target.fetch("publish_id"))
        target.fetch("publish_id")
      end
    end

    def refresh_token!
      response = begin
        Oauth::Http.post_form(
          TOKEN_URL,
          {
            client_key: client_key,
            client_secret: client_secret,
            grant_type: "refresh_token",
            refresh_token: social_account.refresh_token
          },
          {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Cache-Control" => "no-cache"
          }
        )
      rescue Oauth::Http::Error => e
        raise reconnect_required(e.message)
      end

      access_token = response["access_token"]

      raise reconnect_required(response["error_description"]) if access_token.blank?

      social_account.update!(
        access_token: access_token,
        # TikTok rotates the refresh token on every exchange; keeping the old one
        # would break the next refresh.
        refresh_token: response["refresh_token"].presence || social_account.refresh_token,
        expires_at: expires_at_from(response["expires_in"]),
        status: :active
      )
    end

    private

    def with_video(post, &block)
      if post.video.attached?
        blob = post.video.blob

        if blob.byte_size > max_video_bytes
          raise PublishError.new(
            "Could not use that video: #{MediaSource.too_large_message_for(max_video_bytes)}",
            platform: self.class.platform_name
          )
        end

        blob.open do |file|
          yield MediaSource::Media.new(
            file: file,
            content_type: blob.content_type,
            size: blob.byte_size
          )
        end
      else
        source_url = post.media_urls.first

        if source_url.blank?
          raise PublishError.new(
            "TikTok posts need a video. Upload a file or add a video URL.",
            platform: self.class.platform_name
          )
        end

        MediaSource.fetch(source_url, max_bytes: max_video_bytes, &block)
      end
    rescue MediaSource::Error => e
      raise PublishError.new(
        "Could not use that video: #{e.message}",
        platform: self.class.platform_name
      )
    end

    def wait_until_in_inbox(publish_id)
      STATUS_ATTEMPTS.times do |attempt|
        payload = post_json(STATUS_URL, publish_id: publish_id)
        status = payload.dig("data", "status").to_s

        return if INBOX_READY_STATUSES.include?(status)

        if status == "FAILED"
          reason = payload.dig("data", "fail_reason").to_s
          raise PublishError.new(
            FAIL_REASON_MESSAGES[reason] ||
              "TikTok could not process the video#{": #{reason}" if reason.present?}.",
            platform: self.class.platform_name,
            retryable: reason == "internal"
          )
        end

        unless IN_FLIGHT_STATUSES.include?(status) || status.blank?
          raise PublishError.new(
            "TikTok reported an unexpected upload status (#{status}).",
            platform: self.class.platform_name,
            retryable: true
          )
        end

        sleep STATUS_WAIT_SECONDS if attempt < STATUS_ATTEMPTS - 1
      end

      raise PublishError.new(
        "TikTok is still processing the video. Open the TikTok app inbox in a minute, " \
        "or try again if nothing arrives.",
        platform: self.class.platform_name,
        retryable: true
      )
    end

    def initialize_upload(media)
      response = post_json(
        INIT_URL,
        source_info: {
          source: "FILE_UPLOAD",
          video_size: media.size,
          chunk_size: media.size,
          total_chunk_count: 1
        }
      )

      data = response["data"] || {}

      if data["upload_url"].blank? || data["publish_id"].blank?
        raise PublishError.new(
          "TikTok did not return an upload target.",
          platform: self.class.platform_name,
          retryable: true
        )
      end

      data
    end

    # TikTok signals failure both with an HTTP status and with an error code in a
    # 200 body, so both paths funnel into the same translation.
    def post_json(url, body)
      response = Http.post_json(url, body, bearer: social_account.access_token)
      code = response.dig("error", "code")

      if code.present? && code != "ok"
        raise translate(code, response.dig("error", "message"))
      end

      response
    rescue Http::Error => e
      raise translate(
        e.body.is_a?(Hash) ? e.body.dig("error", "code") : nil,
        e.body.is_a?(Hash) ? e.body.dig("error", "message") : nil,
        fallback: e.message,
        retryable: e.retryable?
      )
    end

    def translate(code, message, fallback: nil, retryable: false)
      if CREDENTIAL_ERROR_CODES.include?(code)
        # The account cannot be used again until the user reconnects, so record
        # that rather than leaving it looking healthy.
        social_account.update!(status: :expired)

        return TokenRefreshError.new(ERROR_MESSAGES[code], platform: self.class.platform_name)
      end

      description = ERROR_MESSAGES[code] ||
                    "TikTok rejected the post: #{message.presence || fallback || code || 'unknown error'}"

      PublishError.new(
        description,
        platform: self.class.platform_name,
        retryable: retryable || RETRYABLE_ERROR_CODES.include?(code)
      )
    end

    def reconnect_required(detail)
      social_account.update!(status: :expired)

      TokenRefreshError.new(
        "Could not refresh your TikTok connection#{" (#{detail})" if detail.present?}. " \
        "Reconnect the account and try again.",
        platform: self.class.platform_name
      )
    end

    def expires_at_from(expires_in)
      return nil if expires_in.blank?

      Time.current + expires_in.to_i.seconds
    end

    def max_video_bytes
      ENV.fetch("TIKTOK_MAX_VIDEO_BYTES", DEFAULT_MAX_VIDEO_BYTES).to_i
    end

    def client_key
      ENV["TIKTOK_CLIENT_KEY"]
    end

    def client_secret
      ENV["TIKTOK_CLIENT_SECRET"]
    end
  end
end
