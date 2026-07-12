# frozen_string_literal: true

module AiSummary
  class Configuration
    DEFAULTS = {
      requests_enabled: false,
      submissions_enabled: false,
      model: "gpt-5-mini",
      reasoning_effort: "minimal",
      prompt_version: "v2",
      schema_version: "v2",
      user_allowance: 3,
      allowance_window_days: 30,
      min_input_tokens: 1_500,
      max_input_tokens: 100_000,
      max_output_tokens: 8_000,
      max_topic_cost_microusd: 500_000,
      batch_topic_threshold: 10,
      max_batch_topics: 100,
      max_queue_age_hours: 24,
      retry_limit: 3,
      monthly_hard_budget_microusd: 15_000_000,
      batch_input_microusd_per_million_tokens: 125_000,
      batch_output_microusd_per_million_tokens: 1_000_000
    }.freeze

    class << self
      def requests_enabled?
        boolean_env("AI_SUMMARY_REQUESTS_ENABLED", DEFAULTS[:requests_enabled]) && !OperationalState.requests_paused?
      end

      def submissions_enabled?
        boolean_env("AI_SUMMARY_SUBMISSIONS_ENABLED", DEFAULTS[:submissions_enabled]) && !OperationalState.submissions_paused?
      end

      def model = ENV.fetch("AI_SUMMARY_MODEL", DEFAULTS[:model])
      def reasoning_effort = ENV.fetch("AI_SUMMARY_REASONING_EFFORT", DEFAULTS[:reasoning_effort])
      def prompt_version = ENV.fetch("AI_SUMMARY_PROMPT_VERSION", DEFAULTS[:prompt_version])
      def schema_version = ENV.fetch("AI_SUMMARY_SCHEMA_VERSION", DEFAULTS[:schema_version])
      def user_allowance = integer_env("AI_SUMMARY_USER_ALLOWANCE", :user_allowance)
      def allowance_window_days = integer_env("AI_SUMMARY_ALLOWANCE_WINDOW_DAYS", :allowance_window_days)
      def min_input_tokens = integer_env("AI_SUMMARY_MIN_INPUT_TOKENS", :min_input_tokens)
      def max_input_tokens = integer_env("AI_SUMMARY_MAX_INPUT_TOKENS", :max_input_tokens)
      def max_output_tokens = integer_env("AI_SUMMARY_MAX_OUTPUT_TOKENS", :max_output_tokens)
      def max_topic_cost_microusd = integer_env("AI_SUMMARY_MAX_TOPIC_COST_MICROUSD", :max_topic_cost_microusd)
      def batch_topic_threshold = integer_env("AI_SUMMARY_BATCH_TOPIC_THRESHOLD", :batch_topic_threshold)
      def max_batch_topics = integer_env("AI_SUMMARY_MAX_BATCH_TOPICS", :max_batch_topics)
      def max_queue_age_hours = integer_env("AI_SUMMARY_MAX_QUEUE_AGE_HOURS", :max_queue_age_hours)
      def retry_limit = integer_env("AI_SUMMARY_RETRY_LIMIT", :retry_limit)
      def monthly_hard_budget_microusd = integer_env("AI_SUMMARY_MONTHLY_HARD_BUDGET_MICROUSD", :monthly_hard_budget_microusd)
      def batch_input_microusd_per_million_tokens = integer_env("AI_SUMMARY_BATCH_INPUT_MICROUSD_PER_MILLION_TOKENS", :batch_input_microusd_per_million_tokens)
      def batch_output_microusd_per_million_tokens = integer_env("AI_SUMMARY_BATCH_OUTPUT_MICROUSD_PER_MILLION_TOKENS", :batch_output_microusd_per_million_tokens)

      private

      def boolean_env(name, default)
        ActiveModel::Type::Boolean.new.cast(ENV.fetch(name, default))
      end

      def integer_env(name, default_key)
        Integer(ENV.fetch(name, DEFAULTS.fetch(default_key)).to_s, 10)
      end
    end
  end
end
