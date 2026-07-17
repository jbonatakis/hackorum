class CreateTopicSummaries < ActiveRecord::Migration[8.0]
  ACTIVE_GENERATION_STATES = %w[queued submitted processing].freeze

  def change
    create_table :topic_summary_generations do |t|
      t.references :topic, null: false, foreign_key: true
      t.string :state, null: false, default: "queued"
      t.integer :source_message_count
      t.references :last_message, foreign_key: { to_table: :messages }
      t.string :source_fingerprint
      t.bigint :estimated_input_tokens
      t.bigint :estimated_output_tokens
      t.bigint :estimated_cost_microusd
      t.bigint :actual_input_tokens
      t.bigint :actual_output_tokens
      t.bigint :actual_cost_microusd
      t.string :provider
      t.string :model
      t.string :provider_batch_id
      t.string :provider_item_id
      t.string :prompt_version
      t.string :schema_version
      t.integer :attempts, null: false, default: 0
      t.string :failure_category
      t.datetime :prepared_at
      t.datetime :submitted_at
      t.datetime :processing_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.datetime :cancelled_at
      t.timestamps
    end

    active_states = ACTIVE_GENERATION_STATES.map { |state| connection.quote(state) }.join(", ")
    add_index :topic_summary_generations,
              :topic_id,
              unique: true,
              where: "state IN (#{active_states})",
              name: "idx_topic_summary_generations_one_active"
    add_index :topic_summary_generations,
              [ :topic_id, :source_fingerprint ],
              where: "source_fingerprint IS NOT NULL",
              name: "idx_topic_summary_generations_source"
    add_index :topic_summary_generations, :provider_batch_id
    add_index :topic_summary_generations, :state

    create_table :topic_summaries do |t|
      t.references :topic_summary_generation, null: false, foreign_key: true, index: { unique: true }
      t.references :topic, null: false, foreign_key: true
      t.references :last_message, null: false, foreign_key: { to_table: :messages }
      t.integer :source_message_count, null: false
      t.string :source_fingerprint, null: false
      t.jsonb :content, null: false, default: {}
      t.string :provider, null: false
      t.string :model, null: false
      t.string :prompt_version, null: false
      t.string :schema_version, null: false
      t.bigint :input_tokens
      t.bigint :output_tokens
      t.bigint :cost_microusd
      t.boolean :current, null: false, default: true
      t.datetime :generated_at, null: false
      t.datetime :removed_at
      t.timestamps
    end

    add_index :topic_summaries,
              :topic_id,
              unique: true,
              where: "current = TRUE AND removed_at IS NULL",
              name: "idx_topic_summaries_one_current"
    add_index :topic_summaries, [ :topic_id, :generated_at ]
    add_index :topic_summaries, [ :topic_id, :source_fingerprint ]
  end
end
