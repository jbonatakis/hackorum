require "rails_helper"

RSpec.describe "AI summary update flow" do
  let(:user) { create(:user, admin: true) }
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
    allow(AiSummary::Configuration).to receive(:requests_enabled?).and_return(true)
    allow(AiSummary::Configuration).to receive(:min_input_tokens).and_return(0)
  end

  it "retains the first version while later sent messages produce a broader replacement" do
    first_request = AiSummary::Request.call(user:, topic:)
    expect(first_request.status).to eq(:initiated)

    first_generation = first_request.generation
    first_source = prepare_for_result(first_generation)
    expect(first_source.message_ids).to eq(initial_messages.map(&:id))

    first_summary = process(first_generation, "The initial discussion considered a proposal.")
    expect(first_summary.source_message_ids).to eq(initial_messages.map(&:id))
    expect(AiSummary::TopicState.call(topic:, user:).status).to eq(:fresh)

    held_messages.each { |message| message.update!(state: Message::STATE_SENT) }

    stale_state = AiSummary::TopicState.call(topic:, user:)
    expect(stale_state.status).to eq(:stale)
    expect(stale_state.summary).to eq(first_summary)
    expect(stale_state.uncovered_count).to eq(2)

    update_request = AiSummary::Request.call(user:, topic:)
    expect(update_request.status).to eq(:initiated)

    updating_state = AiSummary::TopicState.call(topic:, user:)
    expect(updating_state.status).to eq(:updating)
    expect(updating_state.summary).to eq(first_summary)

    second_generation = update_request.generation
    second_source = prepare_for_result(second_generation)
    expect(second_source.message_ids).to eq((initial_messages + held_messages).map(&:id))

    second_summary = process(second_generation, "The later messages resolved the proposal's remaining question.")

    expect(topic.topic_summaries.reload.count).to eq(2)
    expect(first_summary.reload.current).to be false
    expect(second_summary.reload.current).to be true
    expect(second_summary.source_message_count).to eq(4)
    expect(AiSummary::TopicState.call(topic:, user:).status).to eq(:fresh)
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
