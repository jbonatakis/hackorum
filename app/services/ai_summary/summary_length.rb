# frozen_string_literal: true

module AiSummary
  class SummaryLength
    Tier = Data.define(:name, :target_min_words, :target_max_words, :hard_max_words, :section_limits)

    COMPACT = Tier.new(
      name: :compact,
      target_min_words: 300,
      target_max_words: 450,
      hard_max_words: 550,
      section_limits: {
        "overview" => 2,
        "key_points" => 4,
        "conclusions" => 2,
        "disagreements_and_concerns" => 2,
        "open_questions" => 1,
        "current_status_or_next_steps" => 1
      }.freeze
    ).freeze

    STANDARD = Tier.new(
      name: :standard,
      target_min_words: 400,
      target_max_words: 600,
      hard_max_words: 700,
      section_limits: {
        "overview" => 2,
        "key_points" => 5,
        "conclusions" => 2,
        "disagreements_and_concerns" => 2,
        "open_questions" => 2,
        "current_status_or_next_steps" => 2
      }.freeze
    ).freeze

    EXTENDED = Tier.new(
      name: :extended,
      target_min_words: 500,
      target_max_words: 700,
      hard_max_words: 850,
      section_limits: {
        "overview" => 2,
        "key_points" => 5,
        "conclusions" => 2,
        "disagreements_and_concerns" => 3,
        "open_questions" => 3,
        "current_status_or_next_steps" => 2
      }.freeze
    ).freeze

    def self.for_input_tokens(input_tokens)
      case input_tokens.to_i
      when ...8_000 then COMPACT
      when ...30_000 then STANDARD
      else EXTENDED
      end
    end
  end
end
