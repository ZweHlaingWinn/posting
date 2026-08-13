module Auth
  # Revokes the caller's JWTs by rotating their jti.
  #
  # Note this invalidates every outstanding token for the user, not just the one
  # presented - the JTIMatcher strategy stores a single jti per user.
  class LogoutService < ApplicationService
    def initialize(user)
      @user = user
    end

    def call
      return failure(errors: ["Not authenticated"], status: :unauthorized) if @user.nil?

      TokenIssuer.revoke_all_for(@user)

      success(data: { message: "Signed out successfully" })
    end
  end
end
