# frozen_string_literal: true

module AiSummary
  class AdminStatus
    def self.call
      queued = TopicSummaryGeneration.queued
      submitted = TopicSummaryGeneration.where(state: %w[submitted processing])
      {
        queued_count: queued.count,
        oldest_queued_at: queued.minimum(:created_at),
        submitted_count: submitted.count,
        provider_batch_count: submitted.where.not(provider_batch_id: nil).distinct.count(:provider_batch_id),
        completed_count: TopicSummaryGeneration.completed.count,
        failed_count: TopicSummaryGeneration.terminal_failed.count,
        unsupported_count: TopicSummaryGeneration.unsupported.count,
        monthly_spend_microusd: Budget.spent_or_committed_microusd,
        monthly_budget_microusd: Configuration.monthly_hard_budget_microusd,
        automation_enabled: Configuration.automation_enabled?,
        automation_started_at: Configuration.automation_started_at,
        minimum_messages: Configuration.minimum_messages,
        max_automatic_topics_per_run: Configuration.max_automatic_topics_per_run,
        submissions_enabled: Configuration.submissions_enabled?,
        recent_failures: TopicSummaryGeneration.where.not(failure_category: nil).order(updated_at: :desc).limit(20)
      }
    end
  end
end
