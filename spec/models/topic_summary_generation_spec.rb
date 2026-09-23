require "rails_helper"

RSpec.describe TopicSummaryGeneration, type: :model do
  it "permits only one active generation per topic at the database level" do
    topic = create(:topic)
    create(:topic_summary_generation, topic:, state: "queued")

    expect do
      described_class.create!(topic:, state: "submitted")
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows a new active generation after the prior generation is terminal" do
    topic = create(:topic)
    create(:topic_summary_generation, topic:, state: "completed")

    expect(create(:topic_summary_generation, topic:, state: "queued")).to be_queued
  end

  it "allows the same source fingerprint after a generation is terminal" do
    topic = create(:topic)
    message = create(:message, topic:)
    create(:topic_summary_generation, topic:, state: "completed", last_message: message, source_fingerprint: "same")

    duplicate = create(:topic_summary_generation, topic:, state: "terminal_failed", last_message: message, source_fingerprint: "same")
    expect(duplicate).to be_persisted
  end

  it "requires the last message to belong to the generation topic" do
    generation = build(:topic_summary_generation, topic: create(:topic), last_message: create(:message))

    expect(generation).not_to be_valid
    expect(generation.errors[:last_message]).to include("must belong to the generation topic")
  end
end
