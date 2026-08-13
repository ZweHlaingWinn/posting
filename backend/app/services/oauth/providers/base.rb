module Oauth
  module Providers
    # Contract every OAuth provider implements, mirroring the Publishers::Base
    # pattern: one class per platform, resolved through a registry.
    class Base
      # Returned by #exchange_code, normalised so callers never see a
      # provider-specific payload.
      Credentials = Struct.new(
        :external_account_id,
        :external_username,
        :access_token,
        :refresh_token,
        :expires_at,
        :scopes,
        keyword_init: true
      )

      class ConfigurationError < StandardError; end
      class AuthorizationError < StandardError; end

      def self.platform
        name.demodulize.underscore
      end

      # Full URL to send the browser to, including PKCE challenge and state.
      def authorization_url(state:, code_challenge:)
        raise NotImplementedError, "#{self.class} must implement #authorization_url"
      end

      # Trades the authorization code for tokens and identity, returning
      # Credentials.
      def exchange_code(code:, code_verifier:)
        raise NotImplementedError, "#{self.class} must implement #exchange_code"
      end

      # Raises ConfigurationError unless the required ENV vars are present, so a
      # misconfigured deployment fails at connect time with a clear message.
      def validate_configuration!
        missing = required_env_vars.reject { |key| ENV[key].present? }
        return if missing.empty?

        raise ConfigurationError,
              "#{self.class.platform} OAuth is not configured: missing #{missing.join(', ')}"
      end

      def configured?
        required_env_vars.all? { |key| ENV[key].present? }
      end

      private

      def required_env_vars
        []
      end

      # Where the provider sends the browser back. Registered with the provider's
      # developer console, so it must match exactly.
      def redirect_uri
        base = ENV.fetch("BACKEND_URL", "http://localhost:3000")
        "#{base}/api/v1/oauth/#{self.class.platform}/callback"
      end
    end
  end
end
