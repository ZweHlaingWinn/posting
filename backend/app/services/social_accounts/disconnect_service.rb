module SocialAccounts
  # Disconnects a channel.
  #
  # This revokes rather than deletes: the row is kept with its tokens cleared and
  # status set to revoked. Destroying it would cascade to post_targets and their
  # analytics_snapshots, silently erasing the delivery and metrics history of
  # everything ever published to that channel. Reconnecting later reuses the same
  # row via the unique (user, platform, external_account_id) index.
  class DisconnectService < ApplicationService
    def initialize(user:, social_account_id:)
      @user = user
      @social_account_id = social_account_id
    end

    def call
      account = @user.social_accounts.find_by(id: @social_account_id)

      return failure(errors: ["Social account not found"], status: :not_found) if account.nil?

      account.update!(status: :revoked, access_token: nil, refresh_token: nil, expires_at: nil)

      success(data: { social_account: SocialAccountSerializer.call(account) })
    end
  end
end
