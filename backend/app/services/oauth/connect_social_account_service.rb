module Oauth
  # Persists provider credentials as a SocialAccount.
  #
  # Reconnecting an account the user already has must update the existing row
  # rather than fail on the unique index, so this upserts on
  # (user, platform, external_account_id) and resets the status to active.
  class ConnectSocialAccountService < ApplicationService
    def initialize(user:, platform:, credentials:)
      @user = user
      @platform = platform.to_s
      @credentials = credentials
    end

    def call
      if @credentials.external_account_id.blank?
        return failure(errors: ["The provider did not identify the account"])
      end

      account = @user.social_accounts.find_or_initialize_by(
        platform: @platform,
        external_account_id: @credentials.external_account_id
      )

      account.assign_attributes(
        external_username: @credentials.external_username,
        access_token: @credentials.access_token,
        refresh_token: @credentials.refresh_token,
        expires_at: @credentials.expires_at,
        status: :active
      )

      return failure(errors: account.errors.full_messages) unless account.save

      success(data: { social_account: SocialAccountSerializer.call(account) })
    end
  end
end
