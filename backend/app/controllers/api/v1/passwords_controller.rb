module Api
  module V1
    class PasswordsController < BaseController
      # POST /api/v1/auth/password - emails a reset token
      def create
        render_service_result(
          Auth::RequestPasswordResetService.call(email: request_params[:email])
        )
      end

      # PUT /api/v1/auth/password - redeems the token and sets a new password
      def update
        render_service_result(
          Auth::ResetPasswordService.call(
            token: update_params[:reset_password_token],
            password: update_params[:password],
            password_confirmation: update_params[:password_confirmation]
          )
        )
      end

      private

      def request_params
        params.require(:user).permit(:email)
      end

      def update_params
        params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
      end
    end
  end
end
