class AssembleTopicSummaryBatchJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    AiSummary::BatchAssembler.call(force:)
  end
end
