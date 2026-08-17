# Presenter for one post's delivery to one channel.
#
# platform_post_id is TikTok's publish_id for an inbox upload, not a post id:
# the creator has to publish the draft themselves before a real post exists.
class PostTargetSerializer
  def self.call(post_target)
    account = post_target.social_account

    {
      id: post_target.id,
      social_account_id: post_target.social_account_id,
      platform: account.platform,
      external_username: account.external_username,
      status: post_target.status,
      platform_post_id: post_target.platform_post_id,
      error_message: post_target.error_message,
      published_at: post_target.published_at&.iso8601
    }
  end
end
