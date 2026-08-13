module Oauth
  # Step 1 of connecting an account: hand the SPA a URL to send the browser to.
  #
  # The PKCE verifier is generated here and tucked into the encrypted state, so
  # the callback can recover it without any server-side session.
  class BuildAuthorizationUrlService < ApplicationService
    def initialize(user:, platform:)
      @user = user
      @platform = platform.to_s
    end

    def call
      provider = ProviderRegistry.for(@platform)

      verifier = Pkce.generate_verifier
      state = StateToken.encode(
        user_id: @user.id,
        platform: @platform,
        code_verifier: verifier
      )

      url = provider.authorization_url(
        state: state,
        code_challenge: Pkce.challenge_for(verifier)
      )

      success(data: { authorization_url: url, platform: @platform })
    rescue ProviderRegistry::UnsupportedProviderError => e
      failure(errors: [e.message], status: :unprocessable_entity)
    rescue Providers::Base::ConfigurationError => e
      # A deployment problem, not something the user can fix by retrying.
      Rails.logger.error("[oauth] #{e.message}")
      failure(errors: [e.message], status: :service_unavailable)
    end
  end
end
