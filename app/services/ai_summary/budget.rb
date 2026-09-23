# frozen_string_literal: true

module AiSummary
  class Budget
    def self.spent_or_committed_microusd(now: Time.current)
      range = now.beginning_of_month...now.next_month.beginning_of_month
      TopicSummaryGeneration.where(submitted_at: range).sum(<<~SQL.squish)
        CASE
          WHEN state IN ('submitted', 'processing')
            THEN COALESCE(actual_cost_microusd, 0) + COALESCE(estimated_cost_microusd, 0)
          ELSE COALESCE(actual_cost_microusd, 0)
        END
      SQL
    end

    def self.available_microusd(now: Time.current)
      [ Configuration.monthly_hard_budget_microusd - spent_or_committed_microusd(now:), 0 ].max
    end
  end
end
