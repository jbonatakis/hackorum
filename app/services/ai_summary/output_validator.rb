# frozen_string_literal: true

require "json"

module AiSummary
  class OutputValidator
    class InvalidOutput < StandardError; end

    MAX_CLAIM_LENGTH = 2_000
    MAX_CITATIONS_PER_CLAIM = 12

    def self.call(output, covered_message_ids:, length_budget: SummaryLength::COMPACT)
      new(output, covered_message_ids:, length_budget:).call
    end

    def initialize(output, covered_message_ids:, length_budget:)
      @output = output
      @covered_message_ids = covered_message_ids.to_set
      @length_budget = length_budget
    end

    def call
      parsed = output.is_a?(String) ? JSON.parse(output) : output.deep_stringify_keys
      fail_with("top-level output must be an object") unless parsed.is_a?(Hash)
      fail_with("sections do not match schema") unless parsed.keys.sort == Schema::SECTIONS.sort

      parsed.each do |section, claims|
        fail_with("#{section} must be an array") unless claims.is_a?(Array)
        fail_with("#{section} contains too many claims") if claims.size > length_budget.section_limits.fetch(section)
        claims.each { |claim| validate_claim(claim) }
      end
      fail_with("summary contains too many words") if word_count(parsed) > length_budget.hard_max_words
      parsed
    rescue JSON::ParserError => e
      raise InvalidOutput, "invalid JSON: #{e.message}"
    end

    private

    attr_reader :output, :covered_message_ids, :length_budget

    def word_count(parsed)
      parsed.values.flatten.sum { |claim| claim.fetch("text").scan(/\S+/).size }
    end

    def validate_claim(claim)
      fail_with("claim must contain only text and message_ids") unless claim.is_a?(Hash) && claim.keys.sort == %w[message_ids text]
      text = claim["text"]
      ids = claim["message_ids"]
      fail_with("claim text is invalid") unless text.is_a?(String) && text.present? && text.length <= MAX_CLAIM_LENGTH
      fail_with("claim citations are invalid") unless ids.is_a?(Array) && ids.any? && ids.size <= MAX_CITATIONS_PER_CLAIM && ids.all? { |id| id.is_a?(Integer) }
      fail_with("claim cites a message outside the snapshot") unless ids.all? { |id| covered_message_ids.include?(id) }
    end

    def fail_with(message)
      raise InvalidOutput, message
    end
  end
end
