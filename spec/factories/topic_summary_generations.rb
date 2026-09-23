FactoryBot.define do
  factory :topic_summary_generation do
    topic
    state { "queued" }
    attempts { 0 }

    trait :submitted do
      state { "submitted" }
      source_message_count { 1 }
      last_message { association(:message, topic: topic) }
      source_message_ids { [ last_message.id ] }
      sequence(:source_fingerprint) { |n| "source-#{n}" }
      provider { "openai" }
      model { "gpt-5-mini" }
      prompt_version { "v1" }
      schema_version { "v1" }
      prepared_at { 1.hour.ago }
      submitted_at { 30.minutes.ago }
    end
  end
end
