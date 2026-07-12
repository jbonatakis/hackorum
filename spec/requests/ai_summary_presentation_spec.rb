require "rails_helper"

RSpec.describe "AI summary presentation", type: :request do
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  before do
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(0)
  end

  it "shows no active request control to anonymous visitors" do
    get topic_path(topic)

    expect(response.body).to include("No summary has been generated")
    expect(response.body).not_to include("Request a summary")
  end

  it "shows a request control to enrolled users" do
    sign_in_as(create(:user, admin: true))

    get topic_path(topic)

    expect(response.body).to include("Request a summary")
    expect(response.body).to include("limited project capacity")
  end

  it "renders safe structured content and chronological citation links" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    content = AiSummary::Schema::SECTIONS.index_with { [] }
    content["overview"] = [ { "text" => "A useful overview", "message_ids" => [ message.id ] } ]
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message, content:)

    get topic_path(topic)

    expect(response.body).to include("Topic Summary")
    expect(response.body).not_to include("ai-summary-label")
    expect(response.body).to include("A useful overview")
    expect(response.body).to include("href=\"#message-#{message.id}\"")
    expect(response.body).to include("may omit context or contain mistakes")
    expect(response.body).to include("AI-generated summaries")
  end

  it "keeps a stale summary visible with uncovered count" do
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: message, state: "completed")
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: message)
    newer_message = create(:message, topic:, created_at: 1.hour.from_now)

    get topic_path(topic)

    expect(response.body).to include("1 newer message")
    expect(response.body).to include("Newer than summary")
    expect(response.body.scan("Newer than summary").size).to eq(1)
    expect(response.body).to match(/class="[^"]*message-card[^"]*newer-than-summary/)
    expect(response.body).to include("id=\"message-#{newer_message.id}\"")
    expect(response.body).not_to include("Pending")
  end

  it "shows the longer-discussion explanation instead of a request button below the floor" do
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(1_500)
    sign_in_as(create(:user, admin: true))

    get topic_path(topic)

    expect(response.body).to include("This discussion is currently too small for automatic summarization")
    expect(response.body).not_to include("Request a summary")
  end
end
