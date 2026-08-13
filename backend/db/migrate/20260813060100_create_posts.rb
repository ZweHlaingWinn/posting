class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true

      t.text :content
      t.jsonb :media_urls, null: false, default: []

      t.integer :status, null: false, default: 0
      t.datetime :scheduled_at
      t.datetime :published_at

      t.timestamps
    end

    # Drives the "what is due to publish" query in the scheduling worker.
    add_index :posts, %i[status scheduled_at]
  end
end
