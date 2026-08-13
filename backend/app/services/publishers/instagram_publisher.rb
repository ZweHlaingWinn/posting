module Publishers
  # Instagram adapter.
  #
  # Auth: Instagram Graph API, reached through the same Facebook App as
  # FacebookPublisher; the account must be a Business or Creator account linked
  # to a Facebook Page.
  #
  # Publishing: two-step container flow - POST /{ig-user-id}/media to create a
  # container, then POST /{ig-user-id}/media_publish. Media-only, like TikTok.
  # Metrics: GET /{ig-media-id}/insights.
  #
  # Not implemented yet - awaiting credentials and the live API contract.
  class InstagramPublisher < Base
    def self.implemented?
      false
    end
  end
end
