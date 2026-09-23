# frozen_string_literal: true

module AiSummary
  class TopicState
    Result = Data.define(:status, :summary, :generation, :uncovered_count)

    def self.call(topic:)
      new(topic:).call
    end

    def initialize(topic:)
      @topic = topic
    end

    def call
      summary = topic.topic_summaries.current.includes(:last_message).first
      generation = topic.topic_summary_generations.active.order(created_at: :desc).first
      uncovered = summary ? topic.messages.sent.where.not(id: summary.source_message_ids).count : 0

      Result.new(status: resolve_status(summary, generation, uncovered), summary:, generation:,
                 uncovered_count: uncovered)
    end

    private

    attr_reader :topic

    def resolve_status(summary, generation, uncovered)
      return generation ? :updating : (uncovered.positive? ? :stale : :fresh) if summary
      return generation.processing? ? :processing : :queued if generation

      :none
    end
  end
end
