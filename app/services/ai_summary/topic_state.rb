# frozen_string_literal: true

module AiSummary
  class TopicState
    Result = Data.define(:status, :summary, :generation, :subscribed, :uncovered_count, :request_available)

    def self.call(topic:, user: nil)
      new(topic:, user:).call
    end

    def initialize(topic:, user:)
      @topic = topic
      @user = user
    end

    def call
      summary = topic.topic_summaries.current.includes(:last_message).first
      generation = topic.topic_summary_generations.active.order(created_at: :desc).first
      subscribed = generation && user && generation.topic_summary_requests.exists?(user:)
      uncovered = summary ? topic.messages.sent.where.not(id: summary.source_message_ids).count : 0
      status = resolve_status(summary, generation, uncovered)

      Result.new(
        status:,
        summary:,
        generation:,
        subscribed: !!subscribed,
        uncovered_count: uncovered,
        request_available: request_available?(status)
      )
    end

    private

    attr_reader :topic, :user

    def resolve_status(summary, generation, uncovered)
      return generation ? :updating : (uncovered.positive? ? :stale : :fresh) if summary
      return generation.processing? ? :processing : :queued if generation

      latest = topic.topic_summary_generations.terminal.order(created_at: :desc).first
      return :unsupported if latest&.unsupported?
      return :failed if latest&.terminal_failed?
      return :too_small if too_small?

      :missing
    end

    def too_small?
      return false unless Configuration.requests_enabled?
      return false unless user&.has_feature?(:ai_topic_summaries)

      Eligibility.call(topic).reason == :input_too_small
    end

    def request_available?(status)
      user&.has_feature?(:ai_topic_summaries) && Configuration.requests_enabled? && %i[missing stale failed].include?(status)
    end
  end
end
