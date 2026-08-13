FactoryBot.define do
  factory :social_account do
    user
    platform { :twitter }
    status { :active }
    sequence(:external_account_id) { |n| "external-#{n}" }
    sequence(:external_username) { |n| "handle#{n}" }
    access_token { "access-token-value" }
    refresh_token { "refresh-token-value" }
    expires_at { 30.days.from_now }

    trait :facebook_page do
      platform { :facebook }
      # Page tokens obtained via /me/accounts are long-lived and carry no expiry.
      expires_at { nil }
      refresh_token { nil }
    end

    trait :tiktok do
      platform { :tiktok }
    end

    trait :expired do
      status { :expired }
      expires_at { 1.day.ago }
    end
  end
end
