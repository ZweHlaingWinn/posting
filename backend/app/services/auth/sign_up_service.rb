module Auth
  # Registers a new user and returns a usable JWT, so the client is logged in
  # immediately after signup without a second round trip.
  class SignUpService < ApplicationService
    def initialize(params)
      @params = params
    end

    def call
      user = User.new(@params)

      return failure(errors: user.errors.full_messages) unless user.save

      success(
        data: { user: UserSerializer.call(user), token: TokenIssuer.issue_for(user) },
        status: :created
      )
    end
  end
end
