module Posts
  # Deletes a post along with its delivery rows.
  #
  # Anything already sent to a platform stays on that platform; this only removes
  # the local record.
  class DestroyService < ApplicationService
    def initialize(user:, post_id:)
      @user = user
      @post_id = post_id
    end

    def call
      post = @user.posts.includes(post_targets: :social_account).find_by(id: @post_id)

      return failure(errors: ["Post not found"], status: :not_found) if post.nil?

      payload = PostSerializer.call(post)
      post.destroy!

      success(data: { post: payload })
    end
  end
end
