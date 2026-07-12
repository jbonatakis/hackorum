# frozen_string_literal: true

module AiSummary
  class OperationalState
    REQUESTS_PAUSED_KEY = "ai_summary:requests_paused"
    SUBMISSIONS_PAUSED_KEY = "ai_summary:submissions_paused"

    class << self
      def requests_paused? = Rails.cache.read(REQUESTS_PAUSED_KEY) == true
      def submissions_paused? = Rails.cache.read(SUBMISSIONS_PAUSED_KEY) == true
      def pause_requests! = Rails.cache.write(REQUESTS_PAUSED_KEY, true)
      def resume_requests! = Rails.cache.delete(REQUESTS_PAUSED_KEY)
      def pause_submissions! = Rails.cache.write(SUBMISSIONS_PAUSED_KEY, true)
      def resume_submissions! = Rails.cache.delete(SUBMISSIONS_PAUSED_KEY)
    end
  end
end
