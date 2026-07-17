require "rails_helper"

RSpec.describe AiSummary::BatchAssembler do
  class FakeBatchClient
    attr_reader :uploaded_jsonl

    def upload_batch_file(jsonl)
      @uploaded_jsonl = jsonl
      { "id" => "file-1" }
    end

    def create_batch(input_file_id:, metadata:)
      raise "wrong file" unless input_file_id == "file-1"
      raise "missing metadata" unless metadata["feature"]
      { "id" => "batch-1" }
    end
  end

  let(:client) { FakeBatchClient.new }

  before do
    allow(AiSummary::Configuration).to receive(:submissions_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:batch_topic_threshold).and_return(1)
  end

  it "prepares and submits due queued topics as JSONL" do
    generation = create(:topic_summary_generation)
    message = create(:message, topic: generation.topic)

    result = described_class.call(client:)
    line = JSON.parse(client.uploaded_jsonl.lines.first)

    expect(result.status).to eq(:submitted)
    expect(result.generation_ids).to eq([ generation.id ])
    expect(line.fetch("custom_id")).to match(/topic-summary-#{generation.id}-attempt-1/)
    expect(line.fetch("url")).to eq("/v1/chat/completions")
    expect(line.dig("body", "response_format", "type")).to eq("json_schema")
    expect(generation.reload).to be_submitted
    expect(generation.source_message_ids).to eq([ message.id ])
    expect(generation.provider_batch_id).to eq("batch-1")
  end

  it "does nothing before threshold or maximum age" do
    allow(AiSummary::Configuration).to receive(:batch_topic_threshold).and_return(10)
    create(:topic_summary_generation, created_at: 1.hour.ago)

    expect(described_class.call(client:).status).to eq(:not_due)
  end

  it "submits an old request below threshold" do
    allow(AiSummary::Configuration).to receive(:batch_topic_threshold).and_return(10)
    generation = create(:topic_summary_generation, created_at: 25.hours.ago)
    create(:message, topic: generation.topic)

    expect(described_class.call(client:).status).to eq(:submitted)
  end

  it "leaves work queued when no budget is available" do
    generation = create(:topic_summary_generation)
    create(:message, topic: generation.topic)
    allow(AiSummary::Budget).to receive(:available_microusd).and_return(0)

    expect(described_class.call(client:).status).to eq(:no_capacity)
    expect(generation.reload).to be_queued
  end

  it "freezes delayed work only after budget admission" do
    generation = create(:topic_summary_generation)
    first = create(:message, topic: generation.topic, created_at: 2.hours.ago)
    allow(AiSummary::Budget).to receive(:available_microusd).and_return(0)

    expect(described_class.call(client:).status).to eq(:no_capacity)
    expect(generation.reload.prepared_at).to be_nil

    second = create(:message, topic: generation.topic, created_at: 1.hour.ago)
    allow(AiSummary::Budget).to receive(:available_microusd).and_return(1_000_000)

    expect(described_class.call(client:).status).to eq(:submitted)
    expect(generation.reload.source_message_ids).to eq([ first.id, second.id ])
  end
end
