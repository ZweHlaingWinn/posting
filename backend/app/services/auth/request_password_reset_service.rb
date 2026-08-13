module Auth
  # Step 1 of password reset: emails a reset token.
  #
  # Always reports success, even for an unregistered address, so the endpoint
  # cannot be used to discover which emails have accounts.
  class RequestPasswordResetService < ApplicationService
    CONFIRMATION = "If that email address exists, password reset instructions have been sent.".freeze

    def initialize(email:)
      @email = email
    end

    def call
      user = User.find_by(email: @email.to_s.strip.downcase)
      user&.send_reset_password_instructions

      success(data: { message: CONFIRMATION })
    end
  end
end
