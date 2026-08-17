module Api
  module V1
    class PlatformsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/platforms
      def index
        render_service_result(::Platforms::ListService.call)
      end
    end
  end
end
