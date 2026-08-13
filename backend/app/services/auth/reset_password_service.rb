module Auth
  # Step 2 of password reset: redeems the emailed token and sets a new password.
  #
  # On success every previously issued JWT is revoked, so a stolen token cannot
  # outlive the password it was obtained under.
  class ResetPasswordService < ApplicationService
    def initialize(token:, password:, password_confirmation:)
      @token = token
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      user = User.reset_password_by_token(
        reset_password_token: @token,
        password: @password,
        password_confirmation: @password_confirmation
      )

      return failure(errors: user.errors.full_messages) if user.errors.any?

      TokenIssuer.revoke_all_for(user)

      success(data: { message: "Password has been reset successfully" })
    end
  end
end
