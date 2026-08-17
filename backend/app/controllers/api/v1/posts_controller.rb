module Api
  module V1
    class PostsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/posts
      def index
        render_service_result(::Posts::ListService.call(user: current_user))
      end

      # GET /api/v1/posts/:id
      def show
        render_service_result(::Posts::ShowService.call(user: current_user, post_id: params[:id]))
      end

      # POST /api/v1/posts
      def create
        render_service_result(
          ::Posts::CreateService.call(user: current_user, attributes: post_params)
        )
      end

      # PATCH /api/v1/posts/:id
      def update
        render_service_result(
          ::Posts::UpdateService.call(
            user: current_user,
            post_id: params[:id],
            attributes: post_params
          )
        )
      end

      # DELETE /api/v1/posts/:id
      def destroy
        render_service_result(::Posts::DestroyService.call(user: current_user, post_id: params[:id]))
      end

      # POST /api/v1/posts/:id/publish
      #
      # Publishing is synchronous, so this request stays open while the video is
      # downloaded and handed to the platform.
      def publish
        render_service_result(::Posts::PublishService.call(user: current_user, post_id: params[:id]))
      end

      private

      def post_params
        params.require(:post)
              .permit(:content, :publish_now, media_urls: [], social_account_ids: [])
      end
    end
  end
end
