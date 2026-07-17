require "rails_helper"

RSpec.describe "Automatic summary update flow" do
  let(:topic) { create(:topic) }
  let!(:initial_messages) do
    [
      create(:message, topic:, created_at: 4.hours.ago),
      create(:message, topic:, created_at: 3.hours.ago)
    ]
  end
  let!(:held_messages) do
    [
      create(:message, topic:, state: Message::STATE_PENDING, created_at: 2.hours.ago),
      create(:message, topic:, state: Message::STATE_PENDING, created_at: 1.hour.ago)
    ]
  end

  before do
    allow(AiSummary::Configuration).to receive(:automation_started_at).and_return(1.day.ago)
    allow(AiSummary::Configuration).to receive(:automation_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:minimum_messages).and_return(1)
    allow(AiSummary::Configuration).to receive(:max_automatic_topics_per_run).and_return(100)
  end

  it "retains the first version while later sent messages produce a broader replacement" do
    expect(AiSummary::AutomaticScheduler.call.queued_count).to eq(1)
    first_generation = topic.topic_summary_generations.sole
    first_source = prepare_for_result(first_generation)
    expect(first_source.message_ids).to eq(initial_messages.map(&:id))

    first_summary = process(first_generation, "The initial discussion considered a proposal.")
    expect(first_summary.source_message_ids).to eq(initial_messages.map(&:id))
    expect(AiSummary::TopicState.call(topic:).status).to eq(:fresh)

    held_messages.each { |message| message.update!(state: Message::STATE_SENT) }

    stale_state = AiSummary::TopicState.call(topic:)
    expect(stale_state.status).to eq(:stale)
    expect(stale_state.summary).to eq(first_summary)
    expect(stale_state.uncovered_count).to eq(2)

    next_day = 1.day.from_now
    expect(AiSummary::AutomaticScheduler.call(now: next_day).queued_count).to eq(1)

    updating_state = AiSummary::TopicState.call(topic:)
    expect(updating_state.status).to eq(:updating)
    expect(updating_state.summary).to eq(first_summary)

    second_generation = topic.topic_summary_generations.active.sole
    second_source = prepare_for_result(second_generation)
    expect(second_source.message_ids).to eq((initial_messages + held_messages).map(&:id))

    second_summary = process(second_generation, "The later messages resolved the proposal's remaining question.")

    expect(topic.topic_summaries.reload.count).to eq(2)
    expect(first_summary.reload.current).to be false
    expect(second_summary.reload.current).to be true
    expect(second_summary.source_message_count).to eq(4)
    expect(AiSummary::TopicState.call(topic:).status).to eq(:fresh)
  end

  def prepare_for_result(generation)
    source = AiSummary::SnapshotPreparer.call(generation)
    generation.update!(
      state: "submitted",
      attempts: 1,
      provider_batch_id: "batch-#{generation.id}",
      provider_item_id: "summary-generation-#{generation.id}",
      submitted_at: Time.current
    )
    source
  end

  def process(generation, claim)
    content = AiSummary::Schema::SECTIONS.index_with { [] }.merge(
      "overview" => [ { "text" => claim, "message_ids" => generation.source_message_ids } ]
    )
    item = {
      "custom_id" => generation.provider_item_id,
      "response" => {
        "status_code" => 200,
        "body" => {
          "choices" => [ { "message" => { "content" => content.to_json } } ],
          "usage" => { "prompt_tokens" => generation.estimated_input_tokens, "completion_tokens" => 50 }
        }
      },
      "error" => nil
    }

    AiSummary::ResultProcessor.call(generation, item)
  end
end
