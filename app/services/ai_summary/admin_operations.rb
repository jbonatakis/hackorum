# frozen_string_literal: true

module AiSummary
  class AdminOperations
    class << self
      def flush!
        AssembleTopicSummaryBatchJob.perform_later(force: true)
      end

      def poll!
        PollTopicSummaryBatchesJob.perform_later
      end

      def schedule!
        ScheduleAutomaticTopicSummariesJob.perform_later
      end

      def preview
        AutomaticScheduler.call(preview: true)
      end

      def retry!(generation)
        generation.with_lock do
          raise ArgumentError, "generation is not retryable" unless generation.terminal_failed?

          generation.update!(state: "queued", attempts: 0, failure_category: nil, failed_at: nil, next_attempt_at: nil,
                             provider_batch_id: nil, provider_item_id: nil, submitted_at: nil, processing_at: nil)
        end
      end

      def cancel!(generation)
        generation.with_lock do
          raise ArgumentError, "only queued work can be cancelled" unless generation.queued?

          generation.update!(state: "cancelled", cancelled_at: Time.current)
        end
      end

      def remove!(summary)
        summary.update!(current: false, removed_at: Time.current)
      end

      def regenerate!(topic)
        canonical = topic.final_topic
        AdvisoryLock.with_lock("topic-summary-regeneration-#{canonical.id}", wait: true) do
          canonical.topic_summary_generations.active.first || canonical.topic_summary_generations.create!(
            state: "queued",
            provider: "openai",
            model: Configuration.model,
            prompt_version: Configuration.prompt_version,
            schema_version: Configuration.schema_version
          )
        end
      end
    end
  end
end
