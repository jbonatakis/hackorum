require "rails_helper"

RSpec.describe AiSummary::SnapshotPreparer do
  it "freezes complete sent-message coverage and configured versions" do
    generation = create(:topic_summary_generation)
    first = create(:message, topic: generation.topic, created_at: 2.hours.ago)
    last = create(:message, topic: generation.topic, created_at: 1.hour.ago)

    source = described_class.call(generation)
    generation.reload

    expect(source.message_ids).to eq([ first.id, last.id ])
    expect(generation.source_message_count).to eq(2)
    expect(generation.last_message).to eq(last)
    expect(generation.source_fingerprint).to eq(source.fingerprint)
    expect(generation.prepared_at).to be_present
  end

  it "does not change an already prepared snapshot when a new message arrives" do
    generation = create(:topic_summary_generation)
    original = create(:message, topic: generation.topic)
    described_class.call(generation)
    create(:message, topic: generation.topic, created_at: 1.hour.from_now)

    result = described_class.call(generation.reload)

    expect(result.message_ids).to eq([ original.id ])
    expect(generation.last_message).to eq(original)
    expect(generation.source_message_count).to eq(1)
  end

  it "refreshes output and cost estimates for a prepared retry" do
    generation = create(:topic_summary_generation)
    create(:message, topic: generation.topic)
    allow(AiSummary::Configuration).to receive(:max_output_tokens).and_return(2_000)
    described_class.call(generation)
    original_cost = generation.reload.estimated_cost_microusd

    allow(AiSummary::Configuration).to receive(:max_output_tokens).and_return(8_000)
    described_class.call(generation)

    expect(generation.reload.estimated_output_tokens).to eq(8_000)
    expect(generation.estimated_cost_microusd).to be > original_cost
  end

  it "marks oversized work unsupported without freezing a partial source" do
    generation = create(:topic_summary_generation)
    create(:message, topic: generation.topic, body: "A" * 1_000)
    allow(AiSummary::Configuration).to receive(:max_input_tokens).and_return(1)

    expect(described_class.call(generation)).to be_nil
    expect(generation.reload).to be_unsupported
    expect(generation.failure_category).to eq("topic_too_large")
  end
end
