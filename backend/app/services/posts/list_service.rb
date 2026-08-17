module Posts
  # The caller's posts, newest first, each with its per-channel delivery state.
  class ListService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      posts = @user.posts
                   .with_attached_video
                   .includes(post_targets: :social_account)
                   .order(created_at: :desc)

      success(data: { posts: posts.map { |post| PostSerializer.call(post) } })
    end
  end
end
