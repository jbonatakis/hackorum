require "rails_helper"

RSpec.describe "AI summary Activities", type: :request do
  it "renders summary-ready content and canonical deep link" do
    user = create(:user, admin: true)
    summary = create(:topic_summary)
    create(:activity, user:, subject: summary, activity_type: "ai_summary_ready")
    sign_in_as(user)

    get activities_path

    expect(response.body).to include("Summary ready")
    expect(response.body).not_to include("AI summary ready")
    expect(response.body).to include(summary.topic.title)
    expect(response.body).to include("#topic-summary")
    expect(response.body).not_to include("#ai-summary")
  end

  it "finds summary Activity by topic title" do
    user = create(:user, admin: true)
    summary = create(:topic_summary)
    create(:activity, user:, subject: summary, activity_type: "ai_summary_ready")
    sign_in_as(user)

    get activities_path, params: { q: summary.topic.title }

    expect(response.body).to include(summary.topic.title)
  end
end
