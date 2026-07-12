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
        requester_count: TopicSummaryRequest.distinct.count(:user_id),
        monthly_spend_microusd: Budget.spent_or_committed_microusd,
        monthly_budget_microusd: Configuration.monthly_hard_budget_microusd,
        requests_enabled: Configuration.requests_enabled?,
        submissions_enabled: Configuration.submissions_enabled?,
        recent_failures: TopicSummaryGeneration.where.not(failure_category: nil).order(updated_at: :desc).limit(20)
      }
    end
  end
end
