require "rails_helper"

RSpec.describe AiSummary::TopicState do
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  it "reports no public state without a summary or active generation" do
    state = described_class.call(topic:)

    expect(state.status).to eq(:none)
    expect(state.summary).to be_nil
  end

  it "reports queued automatic work" do
    generation = create(:topic_summary_generation, topic:)

    state = described_class.call(topic:)

    expect(state.status).to eq(:queued)
    expect(state.generation).to eq(generation)
  end

  it "reports a current summary as stale after a new sent message" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    create(:message, topic:, created_at: 1.hour.from_now)

    state = described_class.call(topic:)

    expect(state.status).to eq(:stale)
    expect(state.uncovered_count).to eq(1)
  end

  it "keeps a stale summary present while its update is active" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    summary = create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    create(:message, topic:, created_at: 1.hour.from_now)
    create(:topic_summary_generation, topic:, state: "queued")

    state = described_class.call(topic:)

    expect(state.status).to eq(:updating)
    expect(state.summary).to eq(summary)
  end
end
