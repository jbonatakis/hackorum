require "rails_helper"

RSpec.describe AiSummary::Schema do
  it "defines every summary section as a required bounded claim array" do
    schema = described_class.definition

    expect(schema.fetch(:required)).to eq(described_class::SECTIONS)
    expect(schema.fetch(:additionalProperties)).to be false
    expect(schema.fetch(:properties).keys).to eq(described_class::SECTIONS)
  end

  it "uses strict OpenAI JSON Schema response format" do
    format = described_class.response_format

    expect(format.dig(:json_schema, :strict)).to be true
    expect(format.dig(:json_schema, :schema)).to eq(described_class.definition)
  end

  it "constrains citations to frozen snapshot message IDs when supplied" do
    schema = described_class.definition(allowed_message_ids: [ 11, 22 ])
    items = schema.dig(:properties, "overview", :items, :properties, :message_ids, :items)

    expect(items).to eq("$ref": "#/$defs/message_id")
    expect(schema.dig(:"$defs", :message_id)).to eq(type: "integer", enum: [ 11, 22 ])
  end

  it "applies per-section limits from the selected length tier" do
    schema = described_class.definition(length_budget: AiSummary::SummaryLength::EXTENDED)

    expect(schema.dig(:properties, "overview", :maxItems)).to eq(2)
    expect(schema.dig(:properties, "key_points", :maxItems)).to eq(5)
    expect(schema.dig(:properties, "disagreements_and_concerns", :maxItems)).to eq(3)
  end
end
