require "rails_helper"

RSpec.describe AiSummary::Configuration do
  it "uses safe disabled defaults for external work" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_SUMMARY_REQUESTS_ENABLED", false).and_return(false)
    allow(ENV).to receive(:fetch).with("AI_SUMMARY_SUBMISSIONS_ENABLED", false).and_return(false)

    expect(described_class.requests_enabled?).to be false
    expect(described_class.submissions_enabled?).to be false
  end

  it "casts configured values" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_SUMMARY_REQUESTS_ENABLED", false).and_return("true")
    allow(ENV).to receive(:fetch).with("AI_SUMMARY_USER_ALLOWANCE", 3).and_return("7")
    allow(ENV).to receive(:fetch).with("AI_SUMMARY_MODEL", "gpt-5-mini").and_return("configured-model")

    expect(described_class.requests_enabled?).to be true
    expect(described_class.user_allowance).to eq(7)
    expect(described_class.model).to eq("configured-model")
  end
end
