module Api
  module V1
    module Oauth
      # Receives the provider's browser redirect.
      #
      # Unauthenticated by necessity: the request comes from the provider, not
      # from the SPA, so it carries no JWT. The encrypted state parameter is what
      # establishes which user is connecting.
      class CallbacksController < BaseController
        # GET /api/v1/oauth/:platform/callback
        def show
          result = ::Oauth::HandleCallbackService.call(
            platform: params[:platform],
            code: params[:code],
            state: params[:state],
            provider_error: params[:error_description].presence || params[:error].presence
          )

          # A browser lands here, so respond with a redirect back into the SPA
          # rather than JSON.
          redirect_to frontend_redirect_url(result), allow_other_host: true
        end

        private

        def frontend_redirect_url(result)
          query =
            if result.success?
              { connected: params[:platform] }
            else
              { connect_error: result.errors.first, platform: params[:platform] }
            end

          "#{frontend_base_url}/settings/accounts?#{query.to_query}"
        end

        def frontend_base_url
          ENV.fetch("FRONTEND_URL", "http://localhost:5173")
        end
      end
    end
  end
end
