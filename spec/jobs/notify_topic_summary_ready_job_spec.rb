require "rails_helper"

RSpec.describe NotifyTopicSummaryReadyJob do
  it "creates one unread Activity per subscriber and marks delivery" do
    generation = create(:topic_summary_generation, :submitted, state: "completed")
    requests = 2.times.map { create(:topic_summary_request, topic_summary_generation: generation) }
    summary = create(:topic_summary, topic_summary_generation: generation)

    expect do
      described_class.perform_now(summary.id)
    end.to change(Activity, :count).by(2)

    activities = Activity.where(subject: summary, activity_type: "ai_summary_ready")
    expect(activities.pluck(:user_id)).to match_array(requests.map(&:user_id))
    expect(activities.map(&:read_at)).to all(be_nil)
    expect(requests.map { |request| request.reload.notified_at }).to all(be_present)
  end

  it "is idempotent" do
    generation = create(:topic_summary_generation, :submitted, state: "completed")
    create(:topic_summary_request, topic_summary_generation: generation)
    summary = create(:topic_summary, topic_summary_generation: generation)

    2.times { described_class.perform_now(summary.id) }

    expect(Activity.where(subject: summary, activity_type: "ai_summary_ready").count).to eq(1)
  end

  it "does not notify for a removed summary" do
    summary = create(:topic_summary, removed_at: Time.current)

    expect { described_class.perform_now(summary.id) }.not_to change(Activity, :count)
  end
end
