# frozen_string_literal: true

module AiSummary
  class AutomaticScheduler
    Result = Data.define(:status, :candidate_count, :considered_count, :eligible_count, :queued_count, :capped, :reasons)

    def self.call(now: Time.current, preview: false)
      new(now:, preview:).call
    end

    def initialize(now:, preview:)
      @now = now
      @preview = preview
    end

    def call
      return result(:unconfigured) unless Configuration.automation_started_at
      return result(:disabled) unless preview || Configuration.automation_enabled?

      total = candidate_scope.count
      reasons = Hash.new(0)
      considered = 0
      candidate_scope.find_each do |topic|
        break if preview && considered >= Configuration.max_automatic_topics_per_run
        break if !preview && reasons[:queued] >= Configuration.max_automatic_topics_per_run

        considered += 1
        reason = preview ? decision_for(topic) : schedule(topic)
        reasons[reason] += 1
      end

      result = Result.new(
        status: preview ? :previewed : :scheduled,
        candidate_count: total,
        considered_count: considered,
        eligible_count: reasons[:eligible] + reasons[:queued],
        queued_count: reasons[:queued],
        capped: total > considered,
        reasons: reasons.freeze
      )
      instrument(result)
      result
    end

    private

    attr_reader :now, :preview

    def candidate_scope
      @candidate_scope ||= Topic.active
                                .where(last_message_at: Configuration.automation_started_at..)
    end

    def schedule(topic)
      AdvisoryLock.with_lock("automatic-topic-summary-#{topic.id}", wait: true) do
        reason = decision_for(topic.reload)
        next reason unless reason == :eligible

        topic.topic_summary_generations.create!(
          state: "queued",
          provider: "openai",
          model: Configuration.model,
          prompt_version: Configuration.prompt_version,
          schema_version: Configuration.schema_version,
          created_at: now,
          updated_at: now
        )
        :queued
      end || :locked
    rescue ActiveRecord::RecordNotUnique
      :active
    end

    def decision_for(topic)
      return :merged if topic.merged?

      sent = topic.messages.sent
      latest_sent = sent.order(created_at: :desc, id: :desc).first
      return :no_sent_messages unless latest_sent
      return :before_rollout if latest_sent.created_at < Configuration.automation_started_at

      generation = topic.topic_summary_generations.active.order(created_at: :desc).first
      return :active if generation
      return :already_scheduled if topic.topic_summary_generations.where(created_at: cycle_start..now).exists?

      summary = topic.topic_summaries.current.first
      if summary
        return :fresh unless uncovered_sent_messages?(topic, summary)
      else
        latest_summary = topic.topic_summaries.order(generated_at: :desc).first
        return :removed if latest_summary&.removed? && !uncovered_sent_messages?(topic, latest_summary)
        return :too_small if sent.count < Configuration.minimum_messages
      end

      failed = topic.topic_summary_generations
                    .where(state: %w[terminal_failed unsupported])
                    .order(created_at: :desc)
                    .first
      return :unchanged_failure if failed&.last_message_id == latest_sent.id

      :eligible
    end

    def uncovered_sent_messages?(topic, summary)
      topic.messages.sent.where.not(id: summary.source_message_ids).exists?
    end

    def cycle_start
      @cycle_start ||= now.in_time_zone.beginning_of_day
    end

    def result(status)
      Result.new(status:, candidate_count: 0, considered_count: 0, eligible_count: 0, queued_count: 0,
                 capped: false, reasons: {}.freeze)
    end

    def instrument(result)
      ActiveSupport::Notifications.instrument(
        "ai_summary.automatic_scheduler.completed",
        status: result.status,
        candidate_count: result.candidate_count,
        considered_count: result.considered_count,
        eligible_count: result.eligible_count,
        queued_count: result.queued_count,
        capped: result.capped,
        reasons: result.reasons
      )
    end
  end
end
