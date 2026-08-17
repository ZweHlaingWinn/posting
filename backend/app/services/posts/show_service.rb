module Posts
  class ShowService < ApplicationService
    def initialize(user:, post_id:)
      @user = user
      @post_id = post_id
    end

    def call
      post = @user.posts.includes(post_targets: :social_account).find_by(id: @post_id)

      return failure(errors: ["Post not found"], status: :not_found) if post.nil?

      success(data: { post: PostSerializer.call(post) })
    end
  end
end
