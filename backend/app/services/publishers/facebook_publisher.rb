module Publishers
  # Facebook Pages adapter.
  #
  # Auth: a single Facebook App (FACEBOOK_APP_ID/SECRET) serves every user and
  # every Page. The connect flow is: user OAuth -> short-lived user token ->
  # exchange for a long-lived user token -> GET /me/accounts, which returns each
  # Page along with that Page's own access token. One SocialAccount row is
  # stored per Page, holding that Page's token in access_token.
  #
  # Because Page tokens derived from a long-lived user token do not expire,
  # refresh_token is normally blank and ensure_usable_token! is a no-op.
  #
  # Publishing: POST /{page-id}/feed for text and links, /{page-id}/photos or
  # /{page-id}/videos for media.
  # Metrics: GET /{post-id}/insights.
  #
  # Not implemented yet - awaiting credentials and the live API contract.
  class FacebookPublisher < Base
    def self.implemented?
      false
    end
  end
end
