require "rails_helper"

RSpec.describe TopicSummaryRequest, type: :model do
  it "allows one subscription per user and generation" do
    existing = create(:topic_summary_request)
    duplicate = build(:topic_summary_request, topic_summary_generation: existing.topic_summary_generation, user: existing.user)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "requires initiators to consume quota" do
    request = build(:topic_summary_request, request_kind: "initiator", quota_consumed_at: nil)

    expect(request).not_to be_valid
    expect(request.errors[:quota_consumed_at]).to be_present
  end

  it "does not require quota consumption for subscribers" do
    expect(build(:topic_summary_request, request_kind: "subscriber", quota_consumed_at: nil)).to be_valid
  end
end
