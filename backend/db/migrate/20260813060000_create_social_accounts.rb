class CreateSocialAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :social_accounts do |t|
      t.references :user, null: false, foreign_key: true

      t.integer :platform, null: false
      t.integer :status, null: false, default: 0

      # Encrypted at rest via Rails 7 `encrypts`; text because ciphertext is
      # substantially longer than the raw token.
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at

      t.string :external_account_id, null: false
      t.string :external_username

      t.timestamps
    end

    # One row per connected destination. For Facebook this is one row per Page,
    # each holding that Page's own access token.
    add_index :social_accounts, %i[user_id platform external_account_id],
              unique: true,
              name: "index_social_accounts_on_user_platform_external_id"
    add_index :social_accounts, %i[platform status]
  end
end
