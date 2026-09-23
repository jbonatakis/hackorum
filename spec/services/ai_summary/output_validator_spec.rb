require "rails_helper"

RSpec.describe AiSummary::OutputValidator do
  let(:message_ids) { [ 10, 11 ] }
  let(:valid_output) do
    AiSummary::Schema::SECTIONS.index_with { [] }.merge(
      "overview" => [ { "text" => "The proposal was discussed.", "message_ids" => [ 10, 11 ] } ]
    )
  end

  it "returns normalized valid output" do
    expect(described_class.call(valid_output.to_json, covered_message_ids: message_ids)).to eq(valid_output)
  end

  it "rejects unknown sections" do
    output = valid_output.merge("invented" => [])

    expect do
      described_class.call(output, covered_message_ids: message_ids)
    end.to raise_error(described_class::InvalidOutput, /sections/)
  end

  it "rejects a citation outside the frozen snapshot" do
    valid_output["overview"].first["message_ids"] = [ 99 ]

    expect do
      described_class.call(valid_output, covered_message_ids: message_ids)
    end.to raise_error(described_class::InvalidOutput, /outside/)
  end

  it "rejects claims without citations" do
    valid_output["overview"].first["message_ids"] = []

    expect do
      described_class.call(valid_output, covered_message_ids: message_ids)
    end.to raise_error(described_class::InvalidOutput, /citations/)
  end


  it "rejects a section beyond the selected tier's claim limit" do
    valid_output["overview"] = Array.new(3) do
      { "text" => "A distinct supported point.", "message_ids" => [ 10 ] }
    end

    expect do
      described_class.call(valid_output, covered_message_ids: message_ids)
    end.to raise_error(described_class::InvalidOutput, /too many claims/)
  end


  it "rejects output beyond the selected tier's hard total-word limit" do
    AiSummary::Schema::SECTIONS.each do |section|
      valid_output[section] = [ { "text" => ([ "word" ] * 100).join(" "), "message_ids" => [ 10 ] } ]
    end

    expect do
      described_class.call(valid_output, covered_message_ids: message_ids)
    end.to raise_error(described_class::InvalidOutput, /too many words/)
  end


  it "does not reject concise valid output for missing a target minimum" do
    expect do
      described_class.call(valid_output, covered_message_ids: message_ids)
    end.not_to raise_error
  end
end
