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

    trait :with_uploaded_video do
      media_urls { [] }

      after(:build) do |post|
        post.video.attach(
          io: StringIO.new('fake-video-bytes'),
          filename: 'clip.mp4',
          content_type: 'video/mp4'
        )
      end
    end
  end
end
