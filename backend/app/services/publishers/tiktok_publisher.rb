module Publishers
  # TikTok adapter.
  #
  # Auth: TikTok Login Kit, OAuth 2.0. Note TikTok names its credentials
  # client_key / client_secret (TIKTOK_CLIENT_KEY, TIKTOK_CLIENT_SECRET) rather
  # than client_id. Access tokens are short-lived and DO carry a refresh token,
  # so unlike Facebook this adapter must implement refresh_token!.
  #
  # Publishing: the Content Posting API. Two distinct modes, gated by scope:
  #   - video.upload  -> uploads to the creator's drafts for manual posting
  #   - video.publish -> direct post, which requires passing TikTok's app audit
  # Until the app is audited, an unaudited client can only post to private
  # accounts, so the usable path early on is video.upload.
  #
  # Content constraint: TikTok has no text-only post. Post#media_urls must
  # contain a video (or an image set for a photo post); content maps to the
  # caption. Publishing therefore depends on the media pipeline existing.
  #
  # Metrics: the video query endpoint returns view/like/comment/share counts,
  # which map onto AnalyticsSnapshot's impressions/likes/comments/shares.
  # TikTok exposes no click metric, so clicks stays 0.
  #
  # Not implemented yet - awaiting credentials and the live API contract.
  class TiktokPublisher < Base
    def self.implemented?
      false
    end
  end
end
