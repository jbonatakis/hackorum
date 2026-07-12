require "rails_helper"

RSpec.describe "AI summary requests", type: :request do
  let(:topic) { create(:topic) }
  let!(:message) { create(:message, topic:) }

  before do
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(0)
  end

  it "requires authentication" do
    post topic_ai_summary_requests_path(topic)

    expect(response).to redirect_to(new_session_path)
    expect(TopicSummaryGeneration.count).to eq(0)
  end

  it "creates work for an administrator and redirects to the AI summary anchor" do
    sign_in_as(create(:user, admin: true))

    post topic_ai_summary_requests_path(topic)

    expect(response).to redirect_to(topic_path(topic, anchor: "topic-summary"))
    expect(flash[:notice]).to include("Summary requested")
    expect(TopicSummaryGeneration.count).to eq(1)
  end

  it "rejects an unenrolled user" do
    sign_in_as(create(:user, admin: false))

    post topic_ai_summary_requests_path(topic)

    expect(response).to redirect_to(topic_path(topic, anchor: "topic-summary"))
    expect(flash[:alert]).to eq("Topic summaries are not enabled for your account.")
    expect(TopicSummaryGeneration.count).to eq(0)
  end

  it "redirects a merged alias request to the canonical topic" do
    canonical = create(:topic)
    create(:message, topic: canonical)
    merged = create(:topic, merged_into_topic: canonical)
    sign_in_as(create(:user, admin: true))

    post topic_ai_summary_requests_path(merged)

    expect(response).to redirect_to(topic_path(canonical, anchor: "topic-summary"))
    expect(TopicSummaryGeneration.last.topic).to eq(canonical)
  end

  it "explains when a discussion is below the automatic summary floor" do
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(1_500)
    sign_in_as(create(:user, admin: true))

    post topic_ai_summary_requests_path(topic)

    expect(response).to redirect_to(topic_path(topic, anchor: "topic-summary"))
    expect(flash[:alert]).to eq("This discussion is currently too small for automatic summarization.")
    expect(TopicSummaryGeneration.count).to eq(0)
  end
end
