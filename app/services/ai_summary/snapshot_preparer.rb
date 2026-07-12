# frozen_string_literal: true

module AiSummary
  class SnapshotPreparer
    def self.call(generation)
      new(generation).call
    end

    def initialize(generation)
      @generation = generation
    end

    def call
      generation.with_lock do
        return frozen_source if generation.prepared_at?

        source = SourceBuilder.call(generation.topic)
        return mark_unsupported unless source.last_message

        output_tokens = Configuration.max_output_tokens
        cost = Eligibility.estimated_cost(input_tokens: source.estimated_input_tokens, output_tokens:)
        return mark_unsupported if source.estimated_input_tokens > Configuration.max_input_tokens || cost > Configuration.max_topic_cost_microusd

        generation.update!(
          source_message_count: source.message_count,
          source_message_ids: source.message_ids,
          last_message: source.last_message,
          source_fingerprint: source.fingerprint,
          estimated_input_tokens: source.estimated_input_tokens,
          estimated_output_tokens: output_tokens,
          estimated_cost_microusd: cost,
          provider: "openai",
          model: Configuration.model,
          prompt_version: Configuration.prompt_version,
          schema_version: Configuration.schema_version,
          prepared_at: Time.current
        )
        source
      end
    end

    private

    attr_reader :generation

    def frozen_source
      source = SourceBuilder.call(generation.topic, message_ids: generation.source_message_ids)
      unless source.message_ids == generation.source_message_ids && source.fingerprint == generation.source_fingerprint
        generation.update!(state: "terminal_failed", failure_category: "source_snapshot_changed", failed_at: Time.current)
        return nil
      end

      output_tokens = Configuration.max_output_tokens
      cost = Eligibility.estimated_cost(input_tokens: source.estimated_input_tokens, output_tokens:)
      return mark_unsupported if source.estimated_input_tokens > Configuration.max_input_tokens || cost > Configuration.max_topic_cost_microusd

      generation.update!(
        estimated_input_tokens: source.estimated_input_tokens,
        estimated_output_tokens: output_tokens,
        estimated_cost_microusd: cost
      )
      source
    end

    def mark_unsupported
      generation.update!(state: "unsupported", failure_category: "topic_too_large", failed_at: Time.current)
      nil
    end
  end
end
