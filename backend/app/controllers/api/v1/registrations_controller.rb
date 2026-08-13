module Api
  module V1
    class RegistrationsController < BaseController
      # POST /api/v1/auth/signup
      def create
        render_service_result(Auth::SignUpService.call(signup_params))
      end

      private

      def signup_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end
    end
  end
end
