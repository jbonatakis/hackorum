require "rails_helper"

RSpec.describe AiSummary::Request do
  let(:user) { create(:user, admin: true) }
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  before do
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(0)
  end

  it "initiates one queued generation and consumes allowance" do
    result = described_class.call(user:, topic:)

    expect(result.status).to eq(:initiated)
    expect(result.generation).to be_queued
    expect(result.request).to be_initiator
    expect(result.request.quota_consumed_at).to be_present
  end

  it "subscribes another enrolled user to existing work without consuming allowance" do
    first = described_class.call(user:, topic:)
    subscriber = create(:user, admin: true)

    result = described_class.call(user: subscriber, topic:)

    expect(result.status).to eq(:subscribed)
    expect(result.generation).to eq(first.generation)
    expect(result.request).to be_subscriber
    expect(result.request.quota_consumed_at).to be_nil
    expect(topic.topic_summary_generations.count).to eq(1)
  end

  it "is idempotent for repeated requests by one user" do
    first = described_class.call(user:, topic:)
    second = described_class.call(user:, topic:)

    expect(second.status).to eq(:already_subscribed)
    expect(second.request).to eq(first.request)
    expect(TopicSummaryRequest.count).to eq(1)
  end

  it "resolves merged topics before creating work" do
    canonical = create(:topic)
    create(:message, topic: canonical)
    merged = create(:topic, merged_into_topic: canonical)

    result = described_class.call(user:, topic: merged)

    expect(result.topic).to eq(canonical)
    expect(result.generation.topic).to eq(canonical)
  end

  it "does not initiate work without sent messages" do
    topic = create(:topic)
    create(:message, topic:, state: Message::STATE_PENDING)

    expect(described_class.call(user:, topic:).status).to eq(:no_sent_messages)
  end

  it "returns fresh when the current summary covers the latest sent message" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)

    expect(described_class.call(user:, topic:).status).to eq(:fresh)
  end

  it "does not initiate new work when requests are disabled" do
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(false)

    expect(described_class.call(user:, topic:).status).to eq(:requests_disabled)
  end

  it "still permits subscription when new requests are disabled" do
    generation = create(:topic_summary_generation, topic:)
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(false)

    result = described_class.call(user:, topic:)

    expect(result.status).to eq(:subscribed)
    expect(result.generation).to eq(generation)
  end

  it "rejects initiation after the rolling allowance is exhausted" do
    allow(AiSummary::Configuration).to receive(:user_allowance).and_return(3)
    3.times do
      prior_generation = create(:topic_summary_generation, topic: create(:topic), state: "completed")
      create(:topic_summary_request, :initiator, topic_summary_generation: prior_generation, user:, quota_consumed_at: 1.day.ago)
    end

    expect(described_class.call(user:, topic:).status).to eq(:quota_exceeded)
  end

  it "returns unsupported when the complete topic exceeds automatic limits" do
    eligibility = AiSummary::Eligibility::Result.new(
      eligible: false,
      reason: :input_too_large,
      estimated_input_tokens: 100_001,
      estimated_output_tokens: 2_000,
      estimated_cost_microusd: 1
    )
    allow(AiSummary::Eligibility).to receive(:call).and_return(eligibility)

    expect(described_class.call(user:, topic:).status).to eq(:unsupported)
    expect(user.topic_summary_requests).to be_empty
  end

  it "returns too small without creating work below the input floor" do
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(1_500)

    expect(described_class.call(user:, topic:).status).to eq(:too_small)
    expect(user.topic_summary_requests).to be_empty
  end

  it "requires explicit enrollment for non-admin users" do
    user = create(:user, admin: false)

    expect(described_class.call(user:, topic:).status).to eq(:feature_unavailable)

    create(:user_feature, user:, feature: "ai_topic_summaries")
    expect(described_class.call(user:, topic:).status).to eq(:initiated)
  end
end
