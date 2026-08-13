FactoryBot.define do
  factory :analytics_snapshot do
    post_target
    impressions { 100 }
    likes { 10 }
    comments { 2 }
    shares { 1 }
    clicks { 5 }
    fetched_at { Time.current }
  end
end
