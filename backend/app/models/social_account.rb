class SocialAccount < ApplicationRecord
  # One row per connected destination. For Facebook that means one row per Page,
  # each carrying that Page's own access token - a single Facebook App serves
  # every Page and every user.
  belongs_to :user
  has_many :post_targets, dependent: :destroy
  has_many :posts, through: :post_targets

  encrypts :access_token
  encrypts :refresh_token

  enum :platform, {
    twitter: 0,
    linkedin: 1,
    facebook: 2,
    instagram: 3,
    tiktok: 4
  }

  enum :status, {
    active: 0,
    expired: 1,
    revoked: 2,
    error: 3
  }, prefix: true

  validates :external_account_id, presence: true
  validates :external_account_id, uniqueness: { scope: %i[user_id platform] }

  scope :connected, -> { where(status: :active) }

  # True when the platform gave an expiry that has already passed. Accounts
  # without an expiry (long-lived Page tokens, for instance) never report stale.
  def token_expired?
    expires_at.present? && expires_at <= Time.current
  end

  def needs_refresh?
    token_expired? && refresh_token.present?
  end
end
