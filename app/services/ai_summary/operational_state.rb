# frozen_string_literal: true

module AiSummary
  class OperationalState
    AUTOMATION_PAUSED_KEY = "ai_summary:automation_paused"
    SUBMISSIONS_PAUSED_KEY = "ai_summary:submissions_paused"

    class << self
      def automation_paused? = Rails.cache.read(AUTOMATION_PAUSED_KEY) == true
      def submissions_paused? = Rails.cache.read(SUBMISSIONS_PAUSED_KEY) == true
      def pause_automation! = Rails.cache.write(AUTOMATION_PAUSED_KEY, true)
      def resume_automation! = Rails.cache.delete(AUTOMATION_PAUSED_KEY)
      def pause_submissions! = Rails.cache.write(SUBMISSIONS_PAUSED_KEY, true)
      def resume_submissions! = Rails.cache.delete(SUBMISSIONS_PAUSED_KEY)
    end
  end
end
