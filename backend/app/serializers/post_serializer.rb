# Presenter for a post and its per-channel delivery state.
class PostSerializer
  def self.call(post)
    {
      id: post.id,
      content: post.content,
      media_urls: post.media_urls,
      status: post.status,
      scheduled_at: post.scheduled_at&.iso8601,
      published_at: post.published_at&.iso8601,
      created_at: post.created_at&.iso8601,
      targets: post.post_targets.map { |target| PostTargetSerializer.call(target) }
    }
  end
end
