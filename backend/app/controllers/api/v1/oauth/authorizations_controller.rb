module Api
  module V1
    module Oauth
      class AuthorizationsController < BaseController
        before_action :authenticate_user!

        # POST /api/v1/oauth/:platform/authorize
        # Returns the URL the SPA should send the browser to.
        def create
          render_service_result(
            ::Oauth::BuildAuthorizationUrlService.call(
              user: current_user,
              platform: params[:platform]
            )
          )
        end
      end
    end
  end
end
