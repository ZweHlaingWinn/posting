require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Background jobs (including Devise's reset-password mail) run through Sidekiq.
    config.active_job.queue_adapter = :sidekiq

    # VideoAnalyzer would enqueue ActiveStorage::AnalyzeJob (and needs ffprobe).
    # We already validate the file at upload, so skip analysis rather than let a
    # Redis outage fail the request after the bytes have already been stored.
    config.active_storage.analyzers = []
    config.active_storage.previewers = []

    # Active Record Encryption protects SocialAccount#access_token and
    # #refresh_token at rest. Keys come from the environment; generate a set with
    # `bin/rails db:encryption:init`. Development and test supply throwaway keys
    # in their own environment files.
    config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]

    config.generators do |g|
      g.test_framework :rspec, request_specs: true, routing_specs: false, view_specs: false
    end
  end
end
