require "rails_helper"

RSpec.describe AiSummary::Budget do
  it "counts actual cost when known and estimates for submitted work" do
    create(:topic_summary_generation, :submitted, state: "completed", submitted_at: Time.current,
                                                   estimated_cost_microusd: 100, actual_cost_microusd: 80)
    create(:topic_summary_generation, :submitted, state: "processing", submitted_at: Time.current,
                                                   estimated_cost_microusd: 120, actual_cost_microusd: nil)

    expect(described_class.spent_or_committed_microusd).to eq(200)
  end

  it "counts prior attempt spend plus the current reservation while submitted" do
    create(:topic_summary_generation, :submitted, state: "processing", submitted_at: Time.current,
                                                   estimated_cost_microusd: 120, actual_cost_microusd: 30)
    create(:topic_summary_generation, :submitted, state: "queued", submitted_at: Time.current,
                                                   estimated_cost_microusd: 100, actual_cost_microusd: 40)

    expect(described_class.spent_or_committed_microusd).to eq(190)
  end

  it "never reports negative capacity" do
    allow(AiSummary::Configuration).to receive(:monthly_hard_budget_microusd).and_return(1)
    create(:topic_summary_generation, :submitted, state: "completed", submitted_at: Time.current,
                                                   estimated_cost_microusd: 100, actual_cost_microusd: 80)

    expect(described_class.available_microusd).to eq(0)
  end
end
