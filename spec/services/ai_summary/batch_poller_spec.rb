require "rails_helper"

RSpec.describe AiSummary::BatchPoller do
  class FakePollClient
    attr_accessor :batch, :files

    def retrieve_batch(_batch_id) = batch
    def retrieve_file_content(file_id) = files.fetch(file_id)
  end

  let(:client) { FakePollClient.new }

  it "marks a live provider batch processing" do
    generation = create(:topic_summary_generation, :submitted, provider_batch_id: "batch-1")
    client.batch = { "id" => "batch-1", "status" => "in_progress" }

    described_class.call(client:)

    expect(generation.reload).to be_processing
  end

  it "processes completed output items by custom id" do
    generation = create(:topic_summary_generation, :submitted, attempts: 1, provider_batch_id: "batch-1", provider_item_id: "item-1")
    content = AiSummary::Schema::SECTIONS.index_with { [] }
    item = {
      "custom_id" => "item-1",
      "response" => {
        "status_code" => 200,
        "body" => {
          "choices" => [ { "message" => { "content" => content.to_json } } ],
          "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
        }
      },
      "error" => nil
    }
    client.batch = { "id" => "batch-1", "status" => "completed", "output_file_id" => "output", "error_file_id" => nil }
    client.files = { "output" => item.to_json + "\n" }

    described_class.call(client:)

    expect(generation.reload).to be_completed
    expect(generation.topic_summary).to be_present
  end
end
