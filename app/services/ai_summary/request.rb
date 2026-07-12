# frozen_string_literal: true

module AiSummary
  class Request
    Result = Data.define(:status, :topic, :generation, :request, :details)

    def self.call(user:, topic:)
      new(user:, topic:).call
    end

    def initialize(user:, topic:)
      @user = user
      @topic = topic.final_topic
    end

    def call
      return result(:feature_unavailable) unless user.has_feature?(:ai_topic_summaries)

      latest_message = latest_sent_message
      return result(:no_sent_messages) unless latest_message
      return result(:fresh) if fresh_summary?(latest_message)

      AdvisoryLock.with_lock("ai-summary-request-topic-#{topic.id}", wait: true) do
        create_or_subscribe(latest_message)
      end
    end

    private

    attr_reader :user, :topic

    def create_or_subscribe(latest_message)
      TopicSummaryGeneration.transaction do
        if (generation = topic.topic_summary_generations.active.first)
          request = generation.topic_summary_requests.find_or_create_by!(user:) do |record|
            record.request_kind = "subscriber"
          end
          return result(request.previously_new_record? ? :subscribed : :already_subscribed, generation:, request:)
        end

        return result(:fresh) if fresh_summary?(latest_message)
        return result(:requests_disabled) unless Configuration.requests_enabled?

        eligibility = Eligibility.call(topic)
        return result(:too_small, details: eligibility) if eligibility.reason == :input_too_small
        return result(:unsupported, details: eligibility) unless eligibility.eligible?

        user.lock!
        return result(:quota_exceeded) if initiation_quota_exceeded?

        generation = topic.topic_summary_generations.create!(
          state: "queued",
          estimated_input_tokens: eligibility.estimated_input_tokens,
          estimated_output_tokens: eligibility.estimated_output_tokens,
          estimated_cost_microusd: eligibility.estimated_cost_microusd,
          provider: "openai",
          model: Configuration.model,
          prompt_version: Configuration.prompt_version,
          schema_version: Configuration.schema_version
        )
        request = generation.topic_summary_requests.create!(
          user:,
          request_kind: "initiator",
          quota_consumed_at: Time.current
        )
        result(:initiated, generation:, request:, details: eligibility)
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def latest_sent_message
      topic.messages.sent.order(created_at: :desc, id: :desc).first
    end

    def fresh_summary?(latest_message)
      topic.topic_summaries.current.where(last_message_id: latest_message.id).exists?
    end

    def initiation_quota_exceeded?
      window_start = Configuration.allowance_window_days.days.ago
      used = user.topic_summary_requests.where.not(quota_consumed_at: nil).where(quota_consumed_at: window_start..).count
      used >= Configuration.user_allowance
    end

    def result(status, generation: nil, request: nil, details: nil)
      ActiveSupport::Notifications.instrument("ai_summary.request", status:, topic_id: topic.id, user_id: user.id,
                                                                    generation_id: generation&.id)
      Result.new(status:, topic:, generation:, request:, details:)
    end
  end
end
