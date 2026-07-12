require "rails_helper"

RSpec.describe AiSummary::TopicState do
  let(:user) { create(:user, admin: true) }
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  before do
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(0)
  end

  it "reports a missing requestable summary" do
    state = described_class.call(topic:, user:)

    expect(state.status).to eq(:missing)
    expect(state.request_available).to be true
  end

  it "reports whether the current user subscribed to active work" do
    generation = create(:topic_summary_generation, topic:)
    create(:topic_summary_request, topic_summary_generation: generation, user:)

    state = described_class.call(topic:, user:)

    expect(state.status).to eq(:queued)
    expect(state.subscribed).to be true
  end

  it "reports a current summary as stale after a new sent message" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    create(:message, topic:, created_at: 1.hour.from_now)

    state = described_class.call(topic:, user:)

    expect(state.status).to eq(:stale)
    expect(state.uncovered_count).to eq(1)
    expect(state.request_available).to be true
  end

  it "keeps a stale summary present while its update is active" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    summary = create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    create(:message, topic:, created_at: 1.hour.from_now)
    create(:topic_summary_generation, topic:, state: "queued")

    state = described_class.call(topic:, user:)

    expect(state.status).to eq(:updating)
    expect(state.summary).to eq(summary)
  end

  it "reports an otherwise requestable short topic as too small" do
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(1_500)

    state = described_class.call(topic:, user:)

    expect(state.status).to eq(:too_small)
    expect(state.request_available).to be false
  end
end
