class ApplicationController < ActionController::API
  # ActionController::API does not pick up Devise's controller helpers the way
  # ActionController::Base does, so `authenticate_user!` / `current_user` have to
  # be mixed in explicitly.
  include Devise::Controllers::Helpers
end
