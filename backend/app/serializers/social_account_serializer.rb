# Presenter for a connected account.
#
# Tokens are deliberately absent: they are encrypted at rest and must never
# leave the backend.
class SocialAccountSerializer
  def self.call(social_account)
    {
      id: social_account.id,
      platform: social_account.platform,
      status: social_account.status,
      external_account_id: social_account.external_account_id,
      external_username: social_account.external_username,
      expires_at: social_account.expires_at&.iso8601,
      connected_at: social_account.created_at&.iso8601
    }
  end
end
