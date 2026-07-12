FactoryBot.define do
  factory :topic_summary_request do
    topic_summary_generation
    user
    request_kind { "subscriber" }

    trait :initiator do
      request_kind { "initiator" }
      quota_consumed_at { Time.current }
    end
  end
end
