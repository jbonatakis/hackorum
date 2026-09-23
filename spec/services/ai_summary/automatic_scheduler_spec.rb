require "rails_helper"

RSpec.describe AiSummary::AutomaticScheduler do
  let(:now) { Time.zone.parse("2026-07-16 12:00:00") }
  let(:rollout) { now - 2.days }

  before do
    allow(AiSummary::Configuration).to receive(:automation_started_at).and_return(rollout)
    allow(AiSummary::Configuration).to receive(:automation_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:minimum_messages).and_return(10)
    allow(AiSummary::Configuration).to receive(:max_automatic_topics_per_run).and_return(100)
  end

  it "creates no work while automatic scheduling is disabled" do
    allow(AiSummary::Configuration).to receive(:automation_enabled?).and_return(false)
    topic = create(:topic)
    create_list(:message, 10, topic:, created_at: now - 1.hour)

    result = described_class.call(now:)

    expect(result.status).to eq(:disabled)
    expect(TopicSummaryGeneration.count).to eq(0)
  end

  it "queues one unfrozen generation when a topic reaches ten sent messages" do
    topic = create(:topic)
    create_list(:message, 10, topic:, created_at: now - 1.hour)

    result = described_class.call(now:)
    generation = topic.topic_summary_generations.sole

    expect(result.queued_count).to eq(1)
    expect(generation).to be_queued
    expect(generation.prepared_at).to be_nil
    expect(generation.source_message_ids).to be_blank
  end

  it "ignores dormant history until a new sent message arrives" do
    topic = create(:topic)
    create_list(:message, 10, topic:, created_at: rollout - 1.day)

    expect(described_class.call(now:).queued_count).to eq(0)

    create(:message, topic:, created_at: now - 1.hour)
    expect(described_class.call(now:).queued_count).to eq(1)
  end

  it "does not count pending messages toward the initial threshold" do
    topic = create(:topic)
    create_list(:message, 9, topic:, created_at: now - 1.hour)
    create(:message, topic:, state: Message::STATE_PENDING, created_at: now - 30.minutes)

    expect(described_class.call(now:).queued_count).to eq(0)
    expect(topic.topic_summary_generations).to be_empty
  end

  it "queues an update after one newer sent message regardless of the initial threshold" do
    topic = create(:topic)
    covered = create(:message, topic:, created_at: rollout - 1.day)
    generation = create(:topic_summary_generation, :submitted, topic:, last_message: covered, state: "completed",
                                                                  created_at: rollout - 1.day)
    create(:topic_summary, topic_summary_generation: generation, topic:, last_message: covered,
                           generated_at: rollout - 1.day)
    create(:message, topic:, created_at: now - 1.hour)

    expect(described_class.call(now:).queued_count).to eq(1)
    expect(topic.topic_summary_generations.active.count).to eq(1)
  end

  it "does not create another generation in the same daily cycle" do
    topic = create(:topic)
    create_list(:message, 10, topic:, created_at: now - 1.hour)
    described_class.call(now:)
    topic.topic_summary_generations.sole.update!(state: "cancelled", cancelled_at: now)

    expect(described_class.call(now:).queued_count).to eq(0)
    expect(topic.topic_summary_generations.count).to eq(1)
  end

  it "suppresses an unchanged terminal failure" do
    topic = create(:topic)
    messages = create_list(:message, 10, topic:, created_at: now - 1.day)
    create(:topic_summary_generation, :submitted, topic:, last_message: messages.last, state: "terminal_failed",
                                                  created_at: now - 1.day)

    expect(described_class.call(now:).queued_count).to eq(0)
    expect(topic.topic_summary_generations.count).to eq(1)
  end

  it "previews a capped candidate set without creating work" do
    allow(AiSummary::Configuration).to receive(:max_automatic_topics_per_run).and_return(1)
    2.times do
      topic = create(:topic)
      create_list(:message, 10, topic:, created_at: now - 1.hour)
    end

    result = described_class.call(now:, preview: true)

    expect(result.candidate_count).to eq(2)
    expect(result.considered_count).to eq(1)
    expect(result.capped).to be true
    expect(TopicSummaryGeneration.count).to eq(0)
  end
end
