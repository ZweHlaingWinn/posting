class Post < ApplicationRecord
  belongs_to :user
  has_many :post_targets, dependent: :destroy
  has_many :social_accounts, through: :post_targets
  # Purge immediately so we do not enqueue a Sidekiq job that would look for the
  # file on a different Render instance.
  has_one_attached :video, dependent: :purge

  enum :status, {
    draft: 0,
    scheduled: 1,
    published: 2,
    failed: 3
  }, prefix: true

  validates :content, presence: true, unless: :media_attached?
  validates :scheduled_at, presence: true, if: :status_scheduled?
  validate :scheduled_at_must_be_in_the_future, if: :status_scheduled?

  scope :due_for_publishing, lambda { |as_of = Time.current|
    where(status: :scheduled).where(scheduled_at: ..as_of)
  }

  # A post needs either text or media; TikTok and Instagram in particular cannot
  # accept a text-only post.
  def media_attached?
    media_urls.present? || video.attached?
  end

  private

  def scheduled_at_must_be_in_the_future
    return if scheduled_at.blank?
    # Only enforced on the way in; an already-scheduled post whose time has
    # passed is the publisher's problem, not a validation error.
    return unless will_save_change_to_scheduled_at?
    return if scheduled_at > Time.current

    errors.add(:scheduled_at, "must be in the future")
  end
end
