# frozen_string_literal: true

module AiSummary
  class Schema
    SECTIONS = %w[
      overview
      key_points
      conclusions
      disagreements_and_concerns
      open_questions
      current_status_or_next_steps
    ].freeze

    def self.definition(allowed_message_ids: nil, length_budget: SummaryLength::COMPACT)
      message_id = if allowed_message_ids.present?
        { "$ref": "#/$defs/message_id" }
      else
        { type: "integer" }
      end
      claim = {
        type: "object",
        additionalProperties: false,
        properties: {
          text: { type: "string", minLength: 1, maxLength: 2_000 },
          message_ids: {
            type: "array",
            minItems: 1,
            maxItems: 12,
            items: message_id
          }
        },
        required: %w[text message_ids]
      }

      schema = {
        type: "object",
        additionalProperties: false,
        properties: SECTIONS.index_with do |section|
          { type: "array", maxItems: length_budget.section_limits.fetch(section), items: claim }
        end,
        required: SECTIONS
      }
      if allowed_message_ids.present?
        schema[:"$defs"] = {
          message_id: { type: "integer", enum: allowed_message_ids }
        }
      end
      schema
    end

    def self.response_format(allowed_message_ids: nil, length_budget: SummaryLength::COMPACT)
      {
        type: "json_schema",
        json_schema: {
          name: "hackorum_topic_summary",
          strict: true,
          schema: definition(allowed_message_ids:, length_budget:)
        }
      }
    end
  end
end
