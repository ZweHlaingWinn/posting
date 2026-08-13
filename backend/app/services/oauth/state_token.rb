module Oauth
  # The OAuth `state` parameter, carrying everything the callback needs.
  #
  # The callback is a plain browser redirect from the provider, so it has no
  # Authorization header and cannot be tied to a user by JWT. Instead the state
  # is encrypted (not merely signed) with the app's secret and round-trips
  # through the provider: it identifies the user, pins the platform, and hides
  # the PKCE verifier, which must stay confidential to be worth anything.
  #
  # Encryption also makes the state tamper-proof, which is what defeats the CSRF
  # attack the parameter exists to prevent. It expires quickly; within that
  # window a state is replayable in principle, but the authorization code it
  # accompanies is single-use at the provider, so a replay yields nothing.
  class StateToken
    EXPIRY = 10.minutes
    PURPOSE = "oauth_state".freeze

    class InvalidStateError < StandardError; end

    class << self
      def encode(user_id:, platform:, code_verifier:)
        encryptor.encrypt_and_sign(
          { user_id: user_id, platform: platform.to_s, code_verifier: code_verifier }.to_json,
          expires_in: EXPIRY,
          purpose: PURPOSE
        )
      end

      def decode(state)
        raise InvalidStateError, "state is missing" if state.blank?

        payload = encryptor.decrypt_and_verify(state, purpose: PURPOSE)
        raise InvalidStateError, "state is expired or invalid" if payload.nil?

        JSON.parse(payload).symbolize_keys
      rescue ActiveSupport::MessageEncryptor::InvalidMessage,
             ActiveSupport::MessageVerifier::InvalidSignature,
             JSON::ParserError
        raise InvalidStateError, "state is expired or invalid"
      end

      private

      def encryptor
        @encryptor ||= begin
          key = ActiveSupport::KeyGenerator
                .new(Rails.application.secret_key_base)
                .generate_key("oauth state encryption", 32)

          ActiveSupport::MessageEncryptor.new(key)
        end
      end
    end
  end
end
