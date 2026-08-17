module Oauth
  # Step 2 of connecting an account: redeem the authorization code and store the
  # resulting credentials as a SocialAccount.
  #
  # Identity comes from the encrypted state rather than a JWT, because the
  # provider redirects the browser here with no Authorization header.
  class HandleCallbackService < ApplicationService
    def initialize(platform:, code:, state:, provider_error: nil)
      @platform = platform.to_s
      @code = code
      @state = state
      @provider_error = provider_error
    end

    def call
      # The user pressed "Cancel" on the provider's consent screen, or the
      # provider rejected the request outright.
      return failure(errors: [@provider_error]) if @provider_error.present?
      return failure(errors: ["Authorization code is missing"]) if @code.blank?

      payload = StateToken.decode(@state)

      # Pin the platform to the one the state was minted for, so a callback
      # cannot be redirected onto a different provider.
      if payload[:platform] != @platform
        return failure(errors: ["State does not match the requested platform"])
      end

      user = User.find_by(id: payload[:user_id])
      return failure(errors: ["The connecting account no longer exists"]) if user.nil?

      credentials = ProviderRegistry.for(@platform)
                                    .exchange_code(code: @code, code_verifier: payload[:code_verifier])

      account = ConnectSocialAccountService.call(
        user: user,
        platform: @platform,
        credentials: credentials
      )

      return account if account.failure?

      success(data: account.data)
    rescue StateToken::InvalidStateError => e
      failure(errors: [e.message])
    rescue ProviderRegistry::UnsupportedProviderError,
           Providers::Base::ConfigurationError,
           Providers::Base::AuthorizationError => e
      Rails.logger.error("[oauth] #{@platform} callback failed: #{e.message}")
      failure(errors: [e.message])
    rescue ActiveRecord::Encryption::Errors::Base, OpenSSL::Cipher::CipherError => e
      Rails.logger.error("[oauth] #{@platform} callback failed: #{e.class}: #{e.message}")
      failure(errors: [ConnectSocialAccountService.encryption_error_message])
    rescue StandardError => e
      Rails.logger.error("[oauth] #{@platform} callback failed: #{e.class}: #{e.message}")
      failure(errors: [e.message.presence || "Could not complete the #{@platform} connection"])
    end
  end
end
