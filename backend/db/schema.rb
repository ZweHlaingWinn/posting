# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_08_13_060300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "analytics_snapshots", force: :cascade do |t|
    t.bigint "post_target_id", null: false
    t.integer "impressions", default: 0, null: false
    t.integer "likes", default: 0, null: false
    t.integer "comments", default: 0, null: false
    t.integer "shares", default: 0, null: false
    t.integer "clicks", default: 0, null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_target_id", "fetched_at"], name: "index_analytics_snapshots_on_post_target_id_and_fetched_at"
    t.index ["post_target_id"], name: "index_analytics_snapshots_on_post_target_id"
  end

  create_table "post_targets", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "social_account_id", null: false
    t.integer "status", default: 0, null: false
    t.string "platform_post_id"
    t.datetime "published_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "social_account_id"], name: "index_post_targets_on_post_id_and_social_account_id", unique: true
    t.index ["post_id"], name: "index_post_targets_on_post_id"
    t.index ["social_account_id"], name: "index_post_targets_on_social_account_id"
    t.index ["status"], name: "index_post_targets_on_status"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.jsonb "media_urls", default: [], null: false
    t.integer "status", default: 0, null: false
    t.datetime "scheduled_at"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "scheduled_at"], name: "index_posts_on_status_and_scheduled_at"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "social_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "platform", null: false
    t.integer "status", default: 0, null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.string "external_account_id", null: false
    t.string "external_username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform", "status"], name: "index_social_accounts_on_platform_and_status"
    t.index ["user_id", "platform", "external_account_id"], name: "index_social_accounts_on_user_platform_external_id", unique: true
    t.index ["user_id"], name: "index_social_accounts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "analytics_snapshots", "post_targets"
  add_foreign_key "post_targets", "posts"
  add_foreign_key "post_targets", "social_accounts"
  add_foreign_key "posts", "users"
  add_foreign_key "social_accounts", "users"
end
