module Api
  module V1
    class SocialAccountsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/social_accounts
      def index
        render_service_result(::SocialAccounts::ListService.call(user: current_user))
      end

      # DELETE /api/v1/social_accounts/:id
      def destroy
        render_service_result(
          ::SocialAccounts::DisconnectService.call(
            user: current_user,
            social_account_id: params[:id]
          )
        )
      end
    end
  end
end
