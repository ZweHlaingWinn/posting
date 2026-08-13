module Publishers
  # Raised for any failure that a publisher wants the calling job to handle.
  # Adapters translate platform-specific error payloads into this so jobs never
  # branch on a particular API's error format.
  class PublishError < StandardError
    attr_reader :platform, :retryable

    def initialize(message = nil, platform: nil, retryable: false)
      @platform = platform
      @retryable = retryable
      super(message)
    end

    # Rate limits and transient 5xx responses should be retried; a revoked token
    # or a rejected caption should not.
    def retryable?
      @retryable
    end
  end
end
