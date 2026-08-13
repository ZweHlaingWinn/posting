module Publishers
  # The stored credentials are no longer usable and the user must reconnect.
  class TokenRefreshError < PublishError; end
end
