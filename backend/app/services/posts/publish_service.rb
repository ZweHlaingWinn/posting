module Posts
  # Sends a post to every channel that has not received it yet.
  #
  # Each target is delivered independently so one platform rejecting a video
  # never blocks the others, and each failure is recorded on its own target row.
  # The result is a failure only when nothing got through at all.
  class PublishService < ApplicationService
    def initialize(user:, post_id:)
      @user = user
      @post_id = post_id
    end

    def call
      post = @user.posts.with_attached_video.includes(post_targets: :social_account).find_by(id: @post_id)

      return failure(errors: ["Post not found"], status: :not_found) if post.nil?
      return failure(errors: ["This post has already been sent"]) if post.status_published?

      pending = post.post_targets.reject(&:status_published?)

      return failure(errors: ["This post has no channels to send to"]) if pending.empty?

      pending.each { |target| deliver(post, target) }

      finalize(post)
    end

    private

    def deliver(post, target)
      publish_id = Publishers::Registry.for(target.social_account).publish(post, target)

      if publish_id.blank?
        return target.mark_failed!("#{target.platform.titleize} did not return a post reference")
      end

      target.mark_published!(platform_post_id: publish_id)
    rescue Publishers::PublishError => e
      target.mark_failed!(e.message)
    rescue StandardError => e
      # A publisher blowing up in an unexpected way should fail that one delivery,
      # not the whole request. The detail goes to the log, not to the user.
      Rails.logger.error("[Posts::PublishService] target=#{target.id} #{e.class}: #{e.message}")
      target.mark_failed!("Something went wrong sending to #{target.platform.titleize}")
    end

    def finalize(post)
      post.post_targets.reload

      if post.post_targets.any?(&:status_published?)
        post.update!(status: :published, published_at: Time.current)

        success(data: { post: PostSerializer.call(post) })
      else
        post.update!(status: :failed)

        failure(errors: failure_messages(post))
      end
    end

    def failure_messages(post)
      post.post_targets.filter_map(&:error_message).uniq.presence || ["Could not send this post"]
    end
  end
end
