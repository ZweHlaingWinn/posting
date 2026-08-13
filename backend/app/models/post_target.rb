class PostTarget < ApplicationRecord
  # The fan-out record: one per (post, destination) pair, tracking that single
  # delivery independently so one platform failing never blocks the others.
  belongs_to :post
  belongs_to :social_account
  has_many :analytics_snapshots, dependent: :destroy

  enum :status, {
    pending: 0,
    published: 1,
    failed: 2
  }, prefix: true

  validates :social_account_id, uniqueness: { scope: :post_id }
  validates :platform_post_id, presence: true, if: :status_published?

  delegate :platform, to: :social_account

  scope :awaiting_publish, -> { where(status: :pending) }

  def latest_snapshot
    analytics_snapshots.order(fetched_at: :desc).first
  end

  def mark_published!(platform_post_id:, published_at: Time.current)
    update!(
      status: :published,
      platform_post_id: platform_post_id,
      published_at: published_at,
      error_message: nil
    )
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end
end
