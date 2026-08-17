module SocialAccounts
  # Returns the caller's connected channels, newest first.
  class ListService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      accounts = @user.social_accounts.order(created_at: :desc)

      success(data: { social_accounts: accounts.map { |a| SocialAccountSerializer.call(a) } })
    end
  end
end
