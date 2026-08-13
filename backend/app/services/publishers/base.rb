module Publishers
  # Common interface every platform adapter implements.
  #
  # Subclasses provide the platform-specific HTTP work by overriding the three
  # protected hooks at the bottom; the public methods handle the shared
  # concerns (token freshness, error translation) so each adapter stays small.
  class Base
    attr_reader :social_account

    def initialize(social_account)
      @social_account = social_account
    end

    # Whether this adapter can actually talk to its platform yet. Stubs report
    # false so the UI can hide or disable connecting them.
    def self.implemented?
      false
    end

    # Human-readable platform name used in error messages.
    def self.platform_name
      name.demodulize.sub(/Publisher\z/, "").underscore
    end

    # Publishes `post` to this adapter's destination and returns the platform's
    # id for the created post. Raises PublishError on failure.
    def publish(post, post_target)
      ensure_usable_token!
      perform_publish(post, post_target)
    end

    # Returns a hash of metric name => integer for the given target.
    def fetch_metrics(post_target)
      ensure_usable_token!
      perform_fetch_metrics(post_target)
    end

    # Refreshes the stored credentials when the platform reports them expired.
    # Shared here because every OAuth2 platform follows the same shape; the
    # actual token exchange is delegated to the subclass.
    def ensure_usable_token!
      return unless social_account.token_expired?

      unless social_account.needs_refresh?
        social_account.update!(status: :expired)
        raise TokenRefreshError.new(
          "#{self.class.platform_name} credentials expired and cannot be refreshed; " \
          "the account must be reconnected",
          platform: self.class.platform_name
        )
      end

      refresh_token!
    end

    protected

    def perform_publish(_post, _post_target)
      not_implemented(:publish)
    end

    def perform_fetch_metrics(_post_target)
      not_implemented(:fetch_metrics)
    end

    def refresh_token!
      not_implemented(:refresh_token!)
    end

    def not_implemented(method_name)
      raise NotImplementedError,
            "#{self.class} must implement ##{method_name}"
    end
  end
end
