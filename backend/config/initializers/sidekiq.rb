# Defaults to Redis logical database 1 rather than 0, so a local Redis shared
# with another project does not mix queues between apps.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
redis_config = { url: redis_url }
# Render Key Value uses TLS (`rediss://`) for connections from outside the
# private network. Internal service-to-service URLs stay on `redis://`.
if redis_url.start_with?("rediss://")
  redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
