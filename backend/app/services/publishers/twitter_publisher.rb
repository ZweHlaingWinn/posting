module Publishers
  # X/Twitter adapter.
  #
  # Auth: OAuth 2.0 with PKCE, credentials in TWITTER_CLIENT_ID/SECRET.
  # Publishing: POST /2/tweets. Media is uploaded separately via the v1.1 media
  # endpoint and referenced by media_ids.
  # Metrics: GET /2/tweets/:id with tweet.fields=public_metrics.
  #
  # Not implemented yet - awaiting credentials and the live API contract.
  class TwitterPublisher < Base
    def self.implemented?
      false
    end
  end
end
