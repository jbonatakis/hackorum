require "rails_helper"

RSpec.describe AiSummary::SummaryLength do
  it "selects bounded tiers from normalized input size" do
    expect(described_class.for_input_tokens(1_500).name).to eq(:compact)
    expect(described_class.for_input_tokens(7_999).name).to eq(:compact)
    expect(described_class.for_input_tokens(8_000).name).to eq(:standard)
    expect(described_class.for_input_tokens(29_999).name).to eq(:standard)
    expect(described_class.for_input_tokens(30_000).name).to eq(:extended)
    expect(described_class.for_input_tokens(100_000).name).to eq(:extended)
  end

  it "keeps short summaries substantive and caps growth for large topics" do
    compact = described_class::COMPACT
    extended = described_class::EXTENDED

    expect(compact.target_min_words).to be >= 300
    expect(extended.target_max_words - compact.target_max_words).to be <= 300
    expect(extended.hard_max_words).to be <= 850
  end
end
