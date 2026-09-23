require "rails_helper"

RSpec.describe AiSummary::Eligibility do
  it "estimates complete sent topic input and cost" do
    topic = create(:topic)
    create(:message, topic:, subject: "Subject", body: "A" * 400)
    create(:message, topic:, state: Message::STATE_PENDING, body: "B" * 10_000)

    result = described_class.call(topic)

    expect(result).to be_eligible
    expect(result.estimated_input_tokens).to be_between(100, 300)
    expect(result.estimated_cost_microusd).to be_positive
  end

  it "rejects a topic over the configured input limit" do
    topic = create(:topic)
    create(:message, topic:, body: "A" * 1_000)
    allow(AiSummary::Configuration).to receive(:max_input_tokens).and_return(10)

    result = described_class.call(topic)

    expect(result).not_to be_eligible
    expect(result.reason).to eq(:input_too_large)
  end
end
