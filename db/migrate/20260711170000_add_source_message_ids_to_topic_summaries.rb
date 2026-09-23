class AddSourceMessageIdsToTopicSummaries < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_summary_generations, :source_message_ids, :bigint, array: true
    add_column :topic_summary_generations, :next_attempt_at, :datetime
    add_column :topic_summaries, :source_message_ids, :bigint, array: true, null: false, default: []
  end
end
