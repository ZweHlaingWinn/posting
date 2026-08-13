module Publishers
  # Single lookup from platform to adapter class.
  #
  # Jobs and services resolve adapters through here rather than with a case
  # statement, so adding a platform means adding one entry and one class.
  class Registry
    ADAPTERS = {
      "twitter" => "Publishers::TwitterPublisher",
      "linkedin" => "Publishers::LinkedinPublisher",
      "facebook" => "Publishers::FacebookPublisher",
      "instagram" => "Publishers::InstagramPublisher",
      "tiktok" => "Publishers::TiktokPublisher"
    }.freeze

    class << self
      # Returns an adapter instance bound to the given account.
      def for(social_account)
        adapter_class(social_account.platform).new(social_account)
      end

      # Class names are resolved lazily so Rails' autoloader stays in control.
      def adapter_class(platform)
        key = platform.to_s
        class_name = ADAPTERS.fetch(key) do
          raise UnsupportedPlatformError.new(
            "No publisher is registered for platform #{key.inspect}",
            platform: key
          )
        end

        class_name.constantize
      end

      def supported_platforms
        ADAPTERS.keys
      end

      # Platforms whose adapters are fully built. Everything else is a stub.
      def implemented_platforms
        ADAPTERS.keys.select { |platform| adapter_class(platform).implemented? }
      end

      def implemented?(platform)
        adapter_class(platform).implemented?
      end
    end
  end
end
