module Oauth
  module Providers
    # TikTok Login Kit (OAuth 2.0 + PKCE).
    #
    # TikTok names its credentials client_key / client_secret rather than
    # client_id / client_secret, which is why the ENV vars differ in shape from
    # the other providers.
    class Tiktok < Base
      AUTHORIZE_URL = "https://www.tiktok.com/v2/auth/authorize/".freeze
      TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/".freeze
      USER_INFO_URL = "https://open.tiktokapis.com/v2/user/info/".freeze

      # user.info.basic is required to learn the account's open_id, which becomes
      # external_account_id. video.upload posts to the creator's drafts and works
      # before app audit; video.publish (direct post) requires passing audit.
      DEFAULT_SCOPES = "user.info.basic,video.upload".freeze

      USER_INFO_FIELDS = "open_id,display_name,avatar_url".freeze

      def authorization_url(state:, code_challenge:)
        validate_configuration!

        params = {
          client_key: client_key,
          scope: scopes,
          response_type: "code",
          redirect_uri: redirect_uri,
          state: state,
          code_challenge: code_challenge,
          code_challenge_method: Pkce::CHALLENGE_METHOD
        }

        "#{AUTHORIZE_URL}?#{params.to_query}"
      end

      def exchange_code(code:, code_verifier:)
        validate_configuration!

        token = request_token(code, code_verifier)
        access_token = token["access_token"]

        raise AuthorizationError, "TikTok did not return an access token" if access_token.blank?

        profile = fetch_user_info(access_token)

        Credentials.new(
          external_account_id: token["open_id"].presence || profile["open_id"],
          external_username: profile["display_name"],
          access_token: access_token,
          refresh_token: token["refresh_token"],
          expires_at: expires_at_from(token["expires_in"]),
          scopes: token["scope"]
        )
      end

      private

      def request_token(code, code_verifier)
        token = Http.post_form(
          TOKEN_URL,
          {
            client_key: client_key,
            client_secret: client_secret,
            code: code,
            grant_type: "authorization_code",
            redirect_uri: redirect_uri,
            code_verifier: code_verifier
          },
          {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Cache-Control" => "no-cache"
          }
        )

        if token["access_token"].blank? && token["error"].present?
          raise AuthorizationError, "TikTok rejected the authorization code: #{token_error_message(token)}"
        end

        token
      rescue Http::Error => e
        raise AuthorizationError, "TikTok rejected the authorization code: #{describe(e)}"
      end

      def fetch_user_info(access_token)
        response = Http.get_json(
          "#{USER_INFO_URL}?fields=#{USER_INFO_FIELDS}",
          { "Authorization" => "Bearer #{access_token}" }
        )

        response.dig("data", "user") || {}
      rescue Http::Error => e
        raise AuthorizationError, "Could not read the TikTok profile: #{describe(e)}"
      end

      # TikTok reports failures both as HTTP errors and as a 200 with an error
      # body, so surface whichever description is available.
      def describe(error)
        token_error_message(error.body) || error.message
      end

      def token_error_message(payload)
        return if payload.blank?

        payload["error_description"].presence ||
          (payload["error"].is_a?(Hash) ? payload["error"]["message"] || payload["error"]["code"] : payload["error"])
      end

      def expires_at_from(expires_in)
        return nil if expires_in.blank?

        Time.current + expires_in.to_i.seconds
      end

      def client_key
        ENV["TIKTOK_CLIENT_KEY"]
      end

      def client_secret
        ENV["TIKTOK_CLIENT_SECRET"]
      end

      def scopes
        ENV.fetch("TIKTOK_SCOPES", DEFAULT_SCOPES)
      end

      def required_env_vars
        %w[TIKTOK_CLIENT_KEY TIKTOK_CLIENT_SECRET]
      end
    end
  end
end
