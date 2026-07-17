require "rails_helper"

RSpec.describe "Topic summary presentation", type: :request do
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  it "shows no empty summary panel or request action" do
    get topic_path(topic)

    expect(response.body).not_to include("Topic Summary")
    expect(response.body).not_to include("Request a summary")
  end

  it "shows passive status for queued automatic work" do
    create(:topic_summary_generation, topic:)

    get topic_path(topic)

    expect(response.body).to include("A topic summary is queued for this discussion")
    expect(response.body).not_to include("Notify me")
  end

  it "renders safe structured content and chronological citation links" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    content = AiSummary::Schema::SECTIONS.index_with { [] }
    content["overview"] = [ { "text" => "A useful overview", "message_ids" => [ message.id ] } ]
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message, content:)

    get topic_path(topic)

    expect(response.body).to include("Topic Summary")
    expect(response.body).to include("A useful overview")
    expect(response.body).to include("href=\"#message-#{message.id}\"")
    expect(response.body).to include("AI-generated summaries may omit context or contain mistakes")
  end

  it "keeps a stale summary visible with uncovered count" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    newer_message = create(:message, topic:, created_at: 1.hour.from_now)

    get topic_path(topic)

    expect(response.body).to include("1 newer message")
    expect(response.body.scan("Newer than summary").size).to eq(1)
    expect(response.body).to match(/class="[^"]*message-card[^"]*newer-than-summary/)
    expect(response.body).to include("id=\"message-#{newer_message.id}\"")
    expect(response.body).not_to include("Request an updated summary")
  end
end
