require "rails_helper"

RSpec.describe AiSummary::AdminStatus do
  it "reports queue, delivery, and budget health without source content" do
    create(:topic_summary_generation, created_at: 2.hours.ago)

    status = described_class.call

    expect(status[:queued_count]).to eq(1)
    expect(status[:oldest_queued_at]).to be_present
    expect(status[:minimum_messages]).to eq(10)
    expect(status[:monthly_budget_microusd]).to be_positive
    expect(status).not_to have_key(:source)
  end
end
