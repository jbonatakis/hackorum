require "rails_helper"

RSpec.describe AiSummary::AdminStatus do
  it "reports queue, delivery, and budget health without source content" do
    generation = create(:topic_summary_generation, created_at: 2.hours.ago)
    create(:topic_summary_request, topic_summary_generation: generation)

    status = described_class.call

    expect(status[:queued_count]).to eq(1)
    expect(status[:oldest_queued_at]).to be_present
    expect(status[:requester_count]).to eq(1)
    expect(status[:monthly_budget_microusd]).to be_positive
    expect(status).not_to have_key(:source)
  end
end
