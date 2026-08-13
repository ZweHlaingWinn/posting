class AnalyticsSnapshot < ApplicationRecord
  # Append-only time series. Each fetch writes a new row rather than updating an
  # existing one, so historical metrics stay intact and deltas can be computed
  # between any two points.
  belongs_to :post_target

  METRICS = %i[impressions likes comments shares clicks].freeze

  validates :fetched_at, presence: true
  validates(*METRICS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })

  scope :chronological, -> { order(fetched_at: :asc) }

  # Enforces the append-only rule. Guarding updates specifically (rather than
  # marking the record readonly) leaves deletes working, so cascading destroys
  # and retention cleanup still function.
  before_update do
    raise ActiveRecord::ReadOnlyRecord,
          "#{self.class} is append-only; record a new snapshot instead of updating one"
  end
end
