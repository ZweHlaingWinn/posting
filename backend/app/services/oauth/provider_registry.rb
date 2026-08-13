module Oauth
  # Platform to OAuth provider lookup, mirroring Publishers::Registry.
  #
  # Only providers listed here can be connected. TikTok is the first one built;
  # the rest are added as their flows are implemented.
  class ProviderRegistry
    PROVIDERS = {
      "tiktok" => "Oauth::Providers::Tiktok"
    }.freeze

    class UnsupportedProviderError < StandardError; end

    class << self
      def for(platform)
        provider_class(platform).new
      end

      def provider_class(platform)
        key = platform.to_s
        class_name = PROVIDERS.fetch(key) do
          raise UnsupportedProviderError,
                "Connecting #{key.inspect} is not supported yet"
        end

        class_name.constantize
      end

      def supported?(platform)
        PROVIDERS.key?(platform.to_s)
      end

      def supported_platforms
        PROVIDERS.keys
      end

      # Supported platforms whose credentials are actually present in the
      # environment, which is what the frontend should offer to connect.
      def connectable_platforms
        supported_platforms.select { |platform| self.for(platform).configured? }
      end
    end
  end
end
