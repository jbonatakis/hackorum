# frozen_string_literal: true

class AiSummaryRequestsController < ApplicationController
  before_action :require_authentication

  def create
    topic = Topic.find(params[:topic_id])
    result = AiSummary::Request.call(user: current_user, topic:)

    redirect_to topic_path(result.topic, anchor: "topic-summary"), flash_for(result.status)
  end

  private

  def flash_for(status)
    case status
    when :initiated
      { notice: "Summary requested. You will receive an Activity notification when it is ready." }
    when :subscribed
      { notice: "You will receive an Activity notification when the summary is ready." }
    when :already_subscribed
      { notice: "You are already subscribed to this summary." }
    when :fresh
      { notice: "This discussion already has an up-to-date summary." }
    when :unsupported
      { alert: "This discussion is currently too large for automatic summarization." }
    when :too_small
      { alert: "This discussion is currently too small for automatic summarization." }
    when :quota_exceeded
      { alert: "You have reached the current summary request allowance." }
    when :requests_disabled
      { alert: "New summary requests are currently disabled." }
    when :feature_unavailable
      { alert: "Topic summaries are not enabled for your account." }
    when :no_sent_messages
      { alert: "This discussion has no sent messages to summarize." }
    else
      { alert: "The summary request could not be processed." }
    end
  end
end
