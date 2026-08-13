FactoryBot.define do
  factory :post do
    user
    content { "Shipping something new today." }
    media_urls { [] }
    status { :draft }

    trait :scheduled do
      status { :scheduled }
      scheduled_at { 1.hour.from_now }
    end

    trait :published do
      status { :published }
      published_at { 1.hour.ago }
    end

    trait :with_media do
      content { nil }
      media_urls { ["https://cdn.example.com/clip.mp4"] }
    end
  end
end
