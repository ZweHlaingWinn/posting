module Api
  module V1
    module Oauth
      # Receives the provider's browser redirect.
      #
      # Unauthenticated by necessity: the request comes from the provider, not
      # from the SPA, so it carries no JWT. The encrypted state parameter is what
      # establishes which user is connecting.
      class CallbacksController < BaseController
        # Must stay in sync with the Vue `/launches` route. TikTok (and every
        # other provider) can only redirect here, to the API; this controller
        # then bounces the browser into the SPA.
        FRONTEND_RETURN_PATH = "/launches"

        # GET /api/v1/oauth/:platform/callback
        def show
          result = ::Oauth::HandleCallbackService.call(
            platform: params[:platform],
            code: params[:code],
            state: params[:state],
            provider_error: params[:error_description].presence || params[:error].presence
          )

          redirect_to_frontend(result)
        rescue StandardError => e
          # A 500 on this URL leaves the user staring at the API host. Always
          # send them back to the SPA, even when the callback itself blows up.
          Rails.logger.error("[oauth] callback crashed: #{e.class}: #{e.message}")
          redirect_to_frontend(nil, connect_error: "Could not complete the connection")
        end

        private

        def redirect_to_frontend(result, connect_error: nil)
          redirect_to frontend_redirect_url(result, connect_error: connect_error),
                      allow_other_host: true
        end

        def frontend_redirect_url(result, connect_error: nil)
          query =
            if connect_error.present?
              { connect_error: connect_error, platform: params[:platform] }
            elsif result&.success?
              { connected: params[:platform] }
            else
              { connect_error: result&.errors&.first || "Could not complete the connection",
                platform: params[:platform] }
            end

          "#{frontend_base_url}#{FRONTEND_RETURN_PATH}?#{query.to_query}"
        end

        def frontend_base_url
          ENV.fetch("FRONTEND_URL", "http://localhost:5173").to_s.sub(%r{/\z}, "")
        end
      end
    end
  end
end
