module Posts
  # Edits the caption or media of a post that has not gone out yet.
  #
  # Channels are fixed at creation: changing them would orphan the delivery rows
  # that already carry failure history.
  class UpdateService < ApplicationService
    def initialize(user:, post_id:, attributes: {})
      @user = user
      @post_id = post_id
      @attributes = attributes || {}
    end

    def call
      post = @user.posts.includes(post_targets: :social_account).find_by(id: @post_id)

      return failure(errors: ["Post not found"], status: :not_found) if post.nil?
      return failure(errors: ["A post that has been sent cannot be edited"]) if post.status_published?

      post.content = @attributes[:content].presence if @attributes.key?(:content)
      post.media_urls = normalized_media_urls if @attributes.key?(:media_urls)
      post.save!

      success(data: { post: PostSerializer.call(post) })
    rescue ActiveRecord::RecordInvalid => e
      failure(errors: e.record.errors.full_messages)
    end

    private

    def normalized_media_urls
      Array(@attributes[:media_urls]).map { |url| url.to_s.strip }.reject(&:blank?)
    end
  end
end
