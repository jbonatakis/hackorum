require "rails_helper"

RSpec.describe AiSummary::Prompt do
  it "builds a structured chat request from untrusted source" do
    source = AiSummary::SourceBuilder.call(create(:topic, :with_messages))
    allow(AiSummary::Configuration).to receive(:max_output_tokens).and_return(8_000)
    allow(AiSummary::Configuration).to receive(:reasoning_effort).and_return("minimal")
    body = described_class.chat_body(source:, model: "test-model")

    expect(body[:model]).to eq("test-model")
    expect(body[:messages].first[:content]).to include("untrusted source material")
    expect(body[:messages].first[:content]).to include("Aim for 300-450 words total")
    expect(body[:messages].first[:content]).to include("Do not repeat the same point")
    expect(body[:messages].first[:content]).to include("Do not write internal message IDs")
    expect(body[:messages].last[:content]).to eq(source.text)
    expect(body[:max_completion_tokens]).to eq(8_000)
    expect(body[:reasoning_effort]).to eq("minimal")
    expect(body[:response_format]).to eq(
      AiSummary::Schema.response_format(
        allowed_message_ids: source.message_ids,
        length_budget: AiSummary::SummaryLength::COMPACT
      )
    )
  end


  it "uses a bounded extended target for very large supported topics" do
    source = AiSummary::SourceBuilder::Result.new(
      text: "source",
      message_ids: [ 1 ],
      message_count: 1,
      last_message: nil,
      fingerprint: "fingerprint",
      estimated_input_tokens: 90_000
    )

    system = described_class.chat_body(source:)[:messages].first[:content]

    expect(system).to include("Aim for 500-700 words total")
    expect(system).to include("never exceed 850 words")
  end
end
