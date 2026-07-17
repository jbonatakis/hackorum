class PollTopicSummaryBatchesJob < ApplicationJob
  queue_as :default

  def perform
    AiSummary::BatchPoller.call
  end
end
