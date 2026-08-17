module Platforms
  # Describes every platform the product knows about, and what can be done with
  # it right now. The channel strip uses this to decide which "Add channel"
  # tiles are clickable versus shown as coming soon.
  class ListService < ApplicationService
    def call
      platforms = SocialAccount.platforms.keys.map do |platform|
        {
          id: platform,
          name: platform.titleize,
          # Can a user start an OAuth connect flow for this platform?
          connectable: Oauth::ProviderRegistry.supported?(platform) &&
            Oauth::ProviderRegistry.for(platform).configured?,
          # Is the publishing adapter built? Connecting is useful before this is
          # true, but posting is not yet possible.
          publishable: Publishers::Registry.implemented?(platform)
        }
      rescue Oauth::ProviderRegistry::UnsupportedProviderError
        { id: platform, name: platform.titleize, connectable: false, publishable: false }
      end

      success(data: { platforms: platforms })
    end
  end
end
