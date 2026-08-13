module Api
  module V1
    class SessionsController < BaseController
      before_action :authenticate_user!, only: :destroy

      # POST /api/v1/auth/login
      def create
        render_service_result(
          Auth::LoginService.call(email: login_params[:email], password: login_params[:password])
        )
      end

      # DELETE /api/v1/auth/logout
      def destroy
        render_service_result(Auth::LogoutService.call(current_user))
      end

      private

      def login_params
        params.require(:user).permit(:email, :password)
      end
    end
  end
end
