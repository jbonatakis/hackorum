class NotifyTopicSummaryReadyJob < ApplicationJob
  queue_as :default

  def perform(topic_summary_id)
    summary = TopicSummary.find_by(id: topic_summary_id)
    return unless summary && !summary.removed?

    summary.topic_summary_generation.topic_summary_requests.find_each do |request|
      create_activity(request, summary)
    end
  end

  private

  def create_activity(request, summary)
    Activity.find_or_create_by!(user: request.user, subject: summary, activity_type: "ai_summary_ready") do |record|
      record.payload = {
        topic_id: summary.topic_id,
        source_message_count: summary.source_message_count,
        last_message_id: summary.last_message_id,
        generated_at: summary.generated_at.iso8601
      }
      record.read_at = nil
      record.hidden = false
    end
    request.update_column(:notified_at, Time.current) if request.notified_at.nil?
    ActiveSupport::Notifications.instrument("ai_summary.notification.delivered", summary_id: summary.id, user_id: request.user_id)
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
