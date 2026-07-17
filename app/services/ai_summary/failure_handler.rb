# frozen_string_literal: true

module AiSummary
  class FailureHandler
    def self.call(generation, category:, retryable:, usage: nil)
      generation.with_lock do
        return generation if generation.completed? || generation.cancelled?

        usage_attributes = cumulative_usage_attributes(generation, usage)
        if retryable && generation.attempts < Configuration.retry_limit
          generation.update!(
            **usage_attributes,
            state: "queued",
            failure_category: category,
            provider_batch_id: nil,
            provider_item_id: nil,
            processing_at: nil,
            next_attempt_at: Time.current + retry_delay(generation.attempts)
          )
        else
          generation.update!(**usage_attributes, state: "terminal_failed", failure_category: category, failed_at: Time.current)
        end
      end
      generation
    end

    def self.retry_delay(attempts)
      ((2**[ attempts, 8 ].min).minutes) + rand(0..30).seconds
    end
    private_class_method :retry_delay

    def self.cumulative_usage_attributes(generation, usage)
      return {} if usage.blank?

      input_tokens = usage["prompt_tokens"].to_i
      output_tokens = usage["completion_tokens"].to_i
      cost = Eligibility.estimated_cost(input_tokens:, output_tokens:)
      {
        actual_input_tokens: generation.actual_input_tokens.to_i + input_tokens,
        actual_output_tokens: generation.actual_output_tokens.to_i + output_tokens,
        actual_cost_microusd: generation.actual_cost_microusd.to_i + cost
      }
    end
    private_class_method :cumulative_usage_attributes
  end
end
