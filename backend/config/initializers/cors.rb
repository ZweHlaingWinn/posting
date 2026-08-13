# Be sure to restart your server when you modify this file.
#
# Allows the Vue dev server (and, in production, the deployed frontend) to call
# this API cross-origin. Origins come from the environment so that no deployment
# hostname is baked into the source.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:5173").split(",").map(&:strip))

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             # The client reads the JWT from the body, but exposing the header
             # keeps `Authorization`-based flows available to other consumers.
             expose: %w[Authorization],
             max_age: 600
  end
end
