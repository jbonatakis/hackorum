require "rails_helper"

RSpec.describe AiSummary::ResultProcessor do
  let(:generation) { create(:topic_summary_generation, :submitted, attempts: 1) }
  let(:valid_content) do
    AiSummary::Schema::SECTIONS.index_with { [] }.merge(
      "overview" => [ { "text" => "A supported claim", "message_ids" => generation.source_message_ids } ]
    )
  end
  let(:item) do
    {
      "custom_id" => generation.provider_item_id,
      "response" => {
        "status_code" => 200,
        "body" => {
          "choices" => [ { "message" => { "content" => valid_content.to_json } } ],
          "usage" => { "prompt_tokens" => 100, "completion_tokens" => 50 }
        }
      },
      "error" => nil
    }
  end

  it "persists one immutable current summary and reconciles usage" do
    generation.update!(actual_input_tokens: 20, actual_output_tokens: 10, actual_cost_microusd: 13)
    summary = described_class.call(generation, item)

    expect(summary).to be_persisted
    expect(summary.source_message_ids).to eq(generation.source_message_ids)
    expect(generation.reload).to be_completed
    expect(summary.input_tokens).to eq(100)
    expect(summary.output_tokens).to eq(50)
    expect(generation.actual_input_tokens).to eq(120)
    expect(generation.actual_output_tokens).to eq(60)
    expect(generation.actual_cost_microusd).to eq(76)
  end

  it "is idempotent when the same result is processed twice" do
    first = described_class.call(generation, item)
    second = described_class.call(generation.reload, item)

    expect(second).to eq(first)
    expect(TopicSummary.where(topic_summary_generation: generation).count).to eq(1)
  end

  it "requeues invalid output with exponential retry timing" do
    item["response"]["body"]["choices"][0]["message"]["content"] = "not json"

    expect(described_class.call(generation, item)).to be_nil
    expect(generation.reload).to be_queued
    expect(generation.failure_category).to eq("invalid_output")
    expect(generation.next_attempt_at).to be > Time.current
    expect(generation.actual_input_tokens).to eq(100)
    expect(generation.actual_output_tokens).to eq(50)
    expect(generation.actual_cost_microusd).to eq(63)
    expect(generation.submitted_at).to be_present
  end

  it "requeues a successful response with missing content" do
    item["response"]["body"]["choices"][0]["message"].delete("content")

    expect(described_class.call(generation, item)).to be_nil
    expect(generation.reload).to be_queued
    expect(generation.failure_category).to eq("missing_provider_content")
  end

  it "terminally fails after the retry limit" do
    generation.update!(attempts: AiSummary::Configuration.retry_limit)
    item["error"] = { "code" => "batch_expired" }

    described_class.call(generation, item)

    expect(generation.reload).to be_terminal_failed
  end
end
