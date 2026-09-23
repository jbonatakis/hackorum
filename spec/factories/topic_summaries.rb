FactoryBot.define do
  factory :topic_summary do
    association :topic_summary_generation, factory: [ :topic_summary_generation, :submitted ]
    topic { topic_summary_generation.topic }
    last_message { topic_summary_generation.last_message }
    source_message_count { topic_summary_generation.source_message_count }
    source_message_ids { topic_summary_generation.source_message_ids }
    source_fingerprint { topic_summary_generation.source_fingerprint }
    content { { "overview" => [ { "text" => "A concise overview", "message_ids" => [ last_message.id ] } ] } }
    provider { topic_summary_generation.provider }
    model { topic_summary_generation.model }
    prompt_version { topic_summary_generation.prompt_version }
    schema_version { topic_summary_generation.schema_version }
    current { true }
    generated_at { Time.current }

    after(:create) do |summary|
      generation = summary.topic_summary_generation
      generation.update_columns(state: "completed", completed_at: summary.generated_at) unless generation.completed?
    end
  end
end
