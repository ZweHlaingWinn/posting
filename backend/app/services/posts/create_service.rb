module Posts
  # Creates a post and its per-channel targets, optionally sending it right away.
  #
  # Publishing runs inline rather than in a background job: there is no worker
  # process yet, so the request holds open while the video is downloaded and
  # forwarded to the platform.
  class CreateService < ApplicationService
    def initialize(user:, attributes: {})
      @user = user
      @attributes = attributes || {}
    end

    def call
      accounts = resolve_accounts
      return accounts if accounts.is_a?(ServiceResult)

      media_urls = normalized_media_urls
      missing_media = media_required_by(accounts)

      if media_urls.empty? && missing_media.present?
        return failure(
          errors: ["#{missing_media.titleize} posts need a video. Add a video URL."]
        )
      end

      post = create_post(accounts, media_urls)

      return publish(post) if publish_now?

      success(data: { post: PostSerializer.call(post) }, status: :created)
    rescue ActiveRecord::RecordInvalid => e
      failure(errors: e.record.errors.full_messages)
    end

    private

    # Returns the accounts to post to, or a failure ServiceResult explaining why
    # the selection is unusable.
    def resolve_accounts
      ids = Array(@attributes[:social_account_ids]).map(&:to_i).uniq

      return failure(errors: ["Choose at least one channel to post to"]) if ids.empty?

      accounts = @user.social_accounts.connected.where(id: ids).to_a

      if accounts.size != ids.size
        return failure(errors: ["One or more of those channels is not connected"])
      end

      unsupported = accounts.reject { |a| Publishers::Registry.implemented?(a.platform) }

      if unsupported.any?
        return failure(
          errors: unsupported.map { |a| "Publishing to #{a.platform.titleize} is not available yet" }
        )
      end

      accounts
    end

    # The first platform that refuses a text-only post, if any.
    def media_required_by(accounts)
      accounts.find { |a| Publishers::Registry.adapter_class(a.platform).requires_media? }
              &.platform
    end

    def create_post(accounts, media_urls)
      post = nil

      ActiveRecord::Base.transaction do
        post = @user.posts.create!(
          content: @attributes[:content].presence,
          media_urls: media_urls,
          status: :draft
        )

        accounts.each { |account| post.post_targets.create!(social_account: account) }
      end

      post
    end

    def publish(post)
      result = PublishService.call(user: @user, post_id: post.id)

      return result if result.failure?

      # The post itself was still created by this request.
      success(data: result.data, status: :created)
    end

    def publish_now?
      ActiveModel::Type::Boolean.new.cast(@attributes[:publish_now]).present?
    end

    def normalized_media_urls
      Array(@attributes[:media_urls]).map { |url| url.to_s.strip }.reject(&:blank?)
    end
  end
end
