class CreatePostTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :post_targets do |t|
      t.references :post, null: false, foreign_key: true
      t.references :social_account, null: false, foreign_key: true

      t.integer :status, null: false, default: 0
      t.string :platform_post_id
      t.datetime :published_at
      t.text :error_message

      t.timestamps
    end

    # A post fans out to one target per destination, and never twice to the same
    # destination - this index is what makes publish retries idempotent.
    add_index :post_targets, %i[post_id social_account_id], unique: true
    add_index :post_targets, :status
  end
end
