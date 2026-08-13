module Publishers
  # No adapter is registered for the requested platform.
  class UnsupportedPlatformError < PublishError; end
end
