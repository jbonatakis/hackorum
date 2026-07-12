require "rails_helper"

RSpec.describe TopicSummary, type: :model do
  it "allows only one visible current summary per topic at the database level" do
    summary = create(:topic_summary)
    generation = create(:topic_summary_generation, :submitted, topic: summary.topic, state: "completed")

    expect do
      described_class.create!(
        topic_summary_generation: generation,
        topic: summary.topic,
        last_message: generation.last_message,
        source_message_count: 1,
        source_message_ids: generation.source_message_ids,
        source_fingerprint: generation.source_fingerprint,
        content: {},
        provider: "openai",
        model: "gpt-5-mini",
        prompt_version: "v1",
        schema_version: "v1",
        generated_at: Time.current,
        current: true
      )
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "retains a removed summary but excludes it from visible current summaries" do
    summary = create(:topic_summary, removed_at: Time.current)

    expect(described_class.find(summary.id)).to eq(summary)
    expect(described_class.current).not_to include(summary)
  end

  it "requires the last message to belong to the summary topic" do
    summary = build(:topic_summary)
    summary.last_message = create(:message)

    expect(summary).not_to be_valid
    expect(summary.errors[:last_message]).to include("must belong to the summary topic")
  end
end
