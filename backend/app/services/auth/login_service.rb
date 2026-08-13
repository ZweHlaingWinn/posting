module Auth
  # Verifies credentials and mints a JWT.
  #
  # An unknown email and a wrong password return the identical error, so the
  # endpoint cannot be used to enumerate registered accounts.
  class LoginService < ApplicationService
    INVALID_CREDENTIALS = "Invalid email or password".freeze

    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      user = User.find_by(email: @email.to_s.strip.downcase)

      unless user&.valid_password?(@password)
        return failure(errors: [INVALID_CREDENTIALS], status: :unauthorized)
      end

      success(data: { user: UserSerializer.call(user), token: TokenIssuer.issue_for(user) })
    end
  end
end
