require "rails_helper"

RSpec.describe AiSummary::AdminOperations do
  it "requeues a terminal failure idempotently" do
    generation = create(:topic_summary_generation, state: "terminal_failed", attempts: 3, failure_category: "invalid_output", failed_at: Time.current)

    described_class.retry!(generation)

    expect(generation.reload).to be_queued
    expect(generation.attempts).to eq(0)
    expect { described_class.retry!(generation) }.to raise_error(ArgumentError)
  end

  it "cancels only queued work" do
    generation = create(:topic_summary_generation)

    described_class.cancel!(generation)

    expect(generation.reload).to be_cancelled
    expect(generation.cancelled_at).to be_present
  end

  it "removes a summary non-destructively and hides its Activities" do
    summary = create(:topic_summary)
    activity = create(:activity, subject: summary, activity_type: "ai_summary_ready")

    described_class.remove!(summary)

    expect(TopicSummary.find(summary.id)).to be_removed
    expect(summary).not_to be_current
    expect(activity.reload).to be_hidden
  end

  it "queues regeneration without removing the current summary" do
    summary = create(:topic_summary)

    generation = described_class.regenerate!(summary.topic)

    expect(generation).to be_queued
    expect(summary.reload).to be_current
  end
end
