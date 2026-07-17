# frozen_string_literal: true

module AiSummary
  class SnapshotPreparer
    class << self
      def call(generation) = new(generation).call
      def build(generation) = new(generation).build
      def freeze!(generation, source) = new(generation).freeze!(source)
    end

    def initialize(generation)
      @generation = generation
    end

    def call
      return frozen_source if generation.prepared_at?

      source = build
      source && freeze!(source)
    end

    def build
      return frozen_source if generation.prepared_at?

      source = SourceBuilder.call(generation.topic)
      return mark_unsupported("no_sent_messages") unless source.last_message

      output_tokens = Configuration.max_output_tokens
      cost = Eligibility.estimated_cost(input_tokens: source.estimated_input_tokens, output_tokens:)
      return mark_unsupported("topic_too_large", source:) if source.estimated_input_tokens > Configuration.max_input_tokens ||
                                                               cost > Configuration.max_topic_cost_microusd

      source
    end

    def freeze!(source)
      generation.with_lock do
        return frozen_source if generation.prepared_at?
        return unless generation.queued?

        output_tokens = Configuration.max_output_tokens
        cost = Eligibility.estimated_cost(input_tokens: source.estimated_input_tokens, output_tokens:)
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

    def mark_unsupported(category, source: nil)
      attributes = { state: "unsupported", failure_category: category, failed_at: Time.current }
      if source&.last_message
        attributes[:last_message] = source.last_message
        attributes[:source_fingerprint] = source.fingerprint
      end
      generation.update!(attributes)
      nil
    end
  end
end
