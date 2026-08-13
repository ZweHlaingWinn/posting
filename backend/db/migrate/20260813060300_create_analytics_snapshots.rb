class CreateAnalyticsSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :analytics_snapshots do |t|
      t.references :post_target, null: false, foreign_key: true

      t.integer :impressions, null: false, default: 0
      t.integer :likes,       null: false, default: 0
      t.integer :comments,    null: false, default: 0
      t.integer :shares,      null: false, default: 0
      t.integer :clicks,      null: false, default: 0

      t.datetime :fetched_at, null: false

      t.timestamps
    end

    # Append-only time series: rows are never updated, so reads are almost
    # always "the latest snapshot for this target" or a range scan.
    add_index :analytics_snapshots, %i[post_target_id fetched_at]
  end
end
