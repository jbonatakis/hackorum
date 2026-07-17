class ScheduleAutomaticTopicSummariesJob < ApplicationJob
  queue_as :default

  def perform
    result = AiSummary::AutomaticScheduler.call
    AssembleTopicSummaryBatchJob.perform_later(force: true) if result.queued_count.positive?
  end
end
