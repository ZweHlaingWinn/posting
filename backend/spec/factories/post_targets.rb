FactoryBot.define do
  factory :post_target do
    post
    social_account
    status { :pending }

    trait :published do
      status { :published }
      sequence(:platform_post_id) { |n| "platform-post-#{n}" }
      published_at { 1.hour.ago }
    end

    trait :failed do
      status { :failed }
      error_message { "Rate limited by the platform" }
    end
  end
end
