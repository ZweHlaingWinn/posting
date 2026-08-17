Rails.application.routes.draw do
  # Devise's own controllers are not used: this is a JSON API, so every auth
  # endpoint below is served by a thin controller in Api::V1 that delegates to a
  # service object. `skip: :all` keeps the Devise model/Warden integration while
  # suppressing its HTML routes.
  devise_for :users, skip: :all

  namespace :api do
    namespace :v1 do
      post   "auth/signup", to: "registrations#create"
      post   "auth/login",  to: "sessions#create"
      delete "auth/logout", to: "sessions#destroy"

      # Password reset is two steps: request an email, then redeem the token.
      post   "auth/password", to: "passwords#create"
      put    "auth/password", to: "passwords#update"

      resources :social_accounts, only: %i[index destroy]
      resources :platforms, only: :index

      # Connecting a social account. `authorize` is called by the SPA with a JWT;
      # `callback` is a browser redirect from the provider and is therefore
      # unauthenticated, relying on the encrypted state parameter instead.
      scope :oauth, module: :oauth do
        post ":platform/authorize", to: "authorizations#create", as: :oauth_authorize
        get  ":platform/callback",  to: "callbacks#show",        as: :oauth_callback
      end
    end
  end

  # Browsers, crawlers, and Cloudflare hit GET / on the API hostname. Without a
  # root route Rails raises RoutingError and fills the logs with 404 noise.
  root "root#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end

