# frozen_string_literal: true

module AiSummary
  class ResultProcessor
    def self.call(generation, item)
      new(generation, item).call
    end

    def initialize(generation, item)
      @generation = generation
      @item = item
    end

    def call
      usage = nil
      return generation.topic_summary if generation.completed?
      return fail_item(item.dig("error", "code") || "provider_item_error", retryable: true) if item["error"]

      response = item["response"]
      return fail_item("missing_provider_response", retryable: true) unless response
      status = response["status_code"].to_i
      return fail_item("provider_item_http_#{status}", retryable: status == 429 || status >= 500) unless status.between?(200, 299)

      body = response["body"]
      return fail_item("missing_provider_content", retryable: true) unless body.is_a?(Hash)

      usage = body["usage"] || {}
      content = body.dig("choices", 0, "message", "content")
      return fail_item("missing_provider_content", retryable: true, usage:) unless content.is_a?(String) && content.present?

      length = SummaryLength.for_input_tokens(generation.estimated_input_tokens)
      validated = OutputValidator.call(content, covered_message_ids: generation.source_message_ids, length_budget: length)
      finalize!(validated, usage)
    rescue KeyError, TypeError, OutputValidator::InvalidOutput
      fail_item("invalid_output", retryable: true, usage:)
    end

    private

    attr_reader :generation, :item

    def finalize!(content, usage)
      input_tokens = usage["prompt_tokens"].to_i
      output_tokens = usage["completion_tokens"].to_i
      cost = Eligibility.estimated_cost(input_tokens:, output_tokens:)

      summary = TopicSummary.transaction do
        generation.lock!
        return generation.topic_summary if generation.completed?

        generation.topic.topic_summaries.current.update_all(current: false, updated_at: Time.current)
        summary = generation.create_topic_summary!(
          topic: generation.topic,
          last_message: generation.last_message,
          source_message_count: generation.source_message_count,
          source_message_ids: generation.source_message_ids,
          source_fingerprint: generation.source_fingerprint,
          content:,
          provider: generation.provider,
          model: generation.model,
          prompt_version: generation.prompt_version,
          schema_version: generation.schema_version,
          input_tokens:,
          output_tokens:,
          cost_microusd: cost,
          generated_at: Time.current,
          current: true
        )
        generation.update!(
          state: "completed",
          actual_input_tokens: generation.actual_input_tokens.to_i + input_tokens,
          actual_output_tokens: generation.actual_output_tokens.to_i + output_tokens,
          actual_cost_microusd: generation.actual_cost_microusd.to_i + cost,
          completed_at: Time.current,
          failure_category: nil,
          next_attempt_at: nil
        )
        ActiveSupport::Notifications.instrument("ai_summary.generation.completed", generation_id: generation.id,
                                                                                   topic_id: generation.topic_id,
                                                                                   input_tokens:, output_tokens:,
                                                                                   cost_microusd: cost)
        summary
      end
      summary
    end

    def fail_item(category, retryable:, usage: nil)
      FailureHandler.call(generation, category:, retryable:, usage:)
      nil
    end
  end
end
