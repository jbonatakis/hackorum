# frozen_string_literal: true

class Admin::AiSummaryOperationsController < Admin::BaseController
  def active_admin_section = :ai_summaries

  def show
    @status = AiSummary::AdminStatus.call
  end

  def flush
    AiSummary::AdminOperations.flush!
    redirect_to admin_ai_summary_operations_path, notice: "Eligible summary work will be flushed."
  end

  def poll
    AiSummary::AdminOperations.poll!
    redirect_to admin_ai_summary_operations_path, notice: "Completed batches will be polled and processed."
  end

  def pause_requests
    AiSummary::OperationalState.pause_requests!
    redirect_back notice: "Summary requests paused.", fallback_location: admin_ai_summary_operations_path
  end

  def resume_requests
    AiSummary::OperationalState.resume_requests!
    redirect_back notice: "Summary request pause cleared.", fallback_location: admin_ai_summary_operations_path
  end

  def pause_submissions
    AiSummary::OperationalState.pause_submissions!
    redirect_back notice: "Summary submissions paused.", fallback_location: admin_ai_summary_operations_path
  end

  def resume_submissions
    AiSummary::OperationalState.resume_submissions!
    redirect_back notice: "Summary submission pause cleared.", fallback_location: admin_ai_summary_operations_path
  end

  def retry_generation
    AiSummary::AdminOperations.retry!(TopicSummaryGeneration.find(params[:generation_id]))
    redirect_back notice: "Generation requeued.", fallback_location: admin_ai_summary_operations_path
  end

  def cancel_generation
    AiSummary::AdminOperations.cancel!(TopicSummaryGeneration.find(params[:generation_id]))
    redirect_back notice: "Queued generation cancelled.", fallback_location: admin_ai_summary_operations_path
  end

  def remove_summary
    AiSummary::AdminOperations.remove!(TopicSummary.find(params[:summary_id]))
    redirect_back notice: "Summary removed from public display.", fallback_location: admin_ai_summary_operations_path
  end

  def regenerate_topic
    AiSummary::AdminOperations.regenerate!(Topic.find(params[:topic_id]))
    redirect_back notice: "Topic regeneration queued.", fallback_location: admin_ai_summary_operations_path
  end
end
