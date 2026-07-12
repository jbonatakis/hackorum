# frozen_string_literal: true

module AiSummary
  class Eligibility
    Result = Data.define(:eligible, :reason, :estimated_input_tokens, :estimated_output_tokens, :estimated_cost_microusd) do
      def eligible? = eligible
    end

    CHARS_PER_TOKEN = 4
    MESSAGE_OVERHEAD_CHARS = 160

    def self.call(topic)
      sent = topic.messages.sent
      message_count = sent.count
      source_chars = sent.sum("octet_length(COALESCE(subject, '')) + octet_length(COALESCE(body, ''))")
      input_tokens = ((source_chars + (message_count * MESSAGE_OVERHEAD_CHARS)).to_f / CHARS_PER_TOKEN).ceil
      output_tokens = Configuration.max_output_tokens
      cost = estimated_cost(input_tokens:, output_tokens:)

      reason = if input_tokens < Configuration.min_input_tokens
        :input_too_small
      elsif input_tokens > Configuration.max_input_tokens
        :input_too_large
      elsif cost > Configuration.max_topic_cost_microusd
        :cost_too_high
      end

      Result.new(
        eligible: reason.nil?,
        reason:,
        estimated_input_tokens: input_tokens,
        estimated_output_tokens: output_tokens,
        estimated_cost_microusd: cost
      )
    end

    def self.estimated_cost(input_tokens:, output_tokens:)
      token_cost(input_tokens, Configuration.batch_input_microusd_per_million_tokens) +
        token_cost(output_tokens, Configuration.batch_output_microusd_per_million_tokens)
    end

    def self.token_cost(tokens, rate)
      ((tokens * rate) + 999_999) / 1_000_000
    end
    private_class_method :token_cost
  end
end
