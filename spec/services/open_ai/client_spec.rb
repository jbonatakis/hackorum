require "rails_helper"

RSpec.describe OpenAi::Client do
  subject(:client) { described_class.new(api_key: "secret", base_url: "https://api.openai.test") }

  it "uploads a JSONL file for batch purpose" do
    stub = stub_request(:post, "https://api.openai.test/v1/files")
      .with(headers: { "Authorization" => "Bearer secret" })
      .to_return(status: 200, body: { id: "file-1" }.to_json)

    expect(client.upload_batch_file("{}\n")).to eq("id" => "file-1")
    expect(stub).to have_been_requested
    expect(stub.request_pattern.to_s).to include("POST")
  end

  it "creates a 24-hour Chat Completions batch" do
    stub_request(:post, "https://api.openai.test/v1/batches")
      .with(body: hash_including(
        "input_file_id" => "file-1",
        "endpoint" => "/v1/chat/completions",
        "completion_window" => "24h"
      )).to_return(status: 200, body: { id: "batch-1", status: "validating" }.to_json)

    expect(client.create_batch(input_file_id: "file-1").fetch("id")).to eq("batch-1")
  end

  it "retrieves batch and output file content" do
    stub_request(:get, "https://api.openai.test/v1/batches/batch-1")
      .to_return(status: 200, body: { id: "batch-1", status: "completed" }.to_json)
    stub_request(:get, "https://api.openai.test/v1/files/file-1/content")
      .to_return(status: 200, body: "line\n")

    expect(client.retrieve_batch("batch-1").fetch("status")).to eq("completed")
    expect(client.retrieve_file_content("file-1")).to eq("line\n")
  end

  it "classifies rate limits as retryable without exposing response bodies" do
    stub_request(:get, "https://api.openai.test/v1/batches/batch-1")
      .to_return(status: 429, body: { error: { message: "sensitive detail" } }.to_json)

    expect { client.retrieve_batch("batch-1") }
      .to raise_error(described_class::Error) { |error|
        expect(error.category).to eq("rate_limited")
        expect(error).to be_retryable
        expect(error.message).not_to include("sensitive detail")
      }
  end

  it "fails safely when no API key is configured" do
    client = described_class.new(api_key: nil)

    expect { client.retrieve_batch("batch") }
      .to raise_error(described_class::Error) { |error| expect(error.category).to eq("missing_api_key") }
  end
end
