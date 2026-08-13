module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      # The single place a ServiceResult becomes an HTTP response, so every
      # endpoint returns the same success/error envelope.
      def render_service_result(result)
        if result.success?
          render json: result.data, status: result.status
        else
          render json: { errors: result.errors }, status: result.status
        end
      end

      def render_parameter_missing(exception)
        render json: { errors: ["Missing required parameter: #{exception.param}"] },
               status: :bad_request
      end
    end
  end
end
