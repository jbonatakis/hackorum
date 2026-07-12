# frozen_string_literal: true

require "json"

module AiSummary
  class BatchAssembler
    Result = Data.define(:status, :batch_id, :generation_ids)

    def self.call(client: OpenAi::Client.new, force: false)
      new(client:, force:).call
    end

    def initialize(client:, force:)
      @client = client
      @force = force
    end

    def call
      return Result.new(status: :submissions_disabled, batch_id: nil, generation_ids: []) unless Configuration.submissions_enabled?

      AdvisoryLock.with_lock("ai-summary-batch-assembler") do
        assemble_locked
      end || Result.new(status: :locked, batch_id: nil, generation_ids: [])
    end

    private

    attr_reader :client, :force

    def assemble_locked
      scope = TopicSummaryGeneration.queued
                                    .where(next_attempt_at: nil)
                                    .or(TopicSummaryGeneration.queued.where(next_attempt_at: ..Time.current))
                                    .order(:created_at, :id)
      return empty unless force || due?(scope)

      remaining_budget = Budget.available_microusd
      prepared = []
      scope.limit(Configuration.max_batch_topics).each do |generation|
        source = SnapshotPreparer.call(generation)
        next unless source && generation.reload.queued?
        next if generation.estimated_cost_microusd.to_i > remaining_budget

        prepared << [ generation, source ]
        remaining_budget -= generation.estimated_cost_microusd.to_i
      end
      return Result.new(status: :no_capacity, batch_id: nil, generation_ids: []) if prepared.empty?

      lines = prepared.map { |generation, source| request_line(generation, source) }
      mark_submitting!(prepared.map(&:first))
      uploaded = client.upload_batch_file(lines.map { |line| JSON.generate(line) }.join("\n") + "\n")
      batch = client.create_batch(input_file_id: uploaded.fetch("id"), metadata: { "feature" => "hackorum_topic_summaries" })
      generations = prepared.map(&:first)
      TopicSummaryGeneration.where(id: generations.map(&:id)).update_all(
        provider_batch_id: batch.fetch("id"),
        updated_at: Time.current
      )
      Result.new(status: :submitted, batch_id: batch.fetch("id"), generation_ids: generations.map(&:id))
        .tap do |result|
          ActiveSupport::Notifications.instrument("ai_summary.batch.submitted", batch_id: result.batch_id,
                                                                                  generation_count: generations.size)
        end
    rescue OpenAi::Client::Error => e
      handle_submission_error(prepared&.map(&:first) || [], e)
    end

    def due?(scope)
      scope.limit(Configuration.batch_topic_threshold).count >= Configuration.batch_topic_threshold ||
        scope.where(created_at: ..Configuration.max_queue_age_hours.hours.ago).exists?
    end

    def request_line(generation, source)
      custom_id = "topic-summary-#{generation.id}-attempt-#{generation.attempts + 1}"
      generation.provider_item_id = custom_id
      {
        custom_id:,
        method: "POST",
        url: "/v1/chat/completions",
        body: Prompt.chat_body(source:, model: generation.model)
      }
    end

    def mark_submitting!(generations)
      now = Time.current
      generations.each do |generation|
        generation.update!(
          state: "submitted",
          attempts: generation.attempts + 1,
          provider_item_id: generation.provider_item_id,
          submitted_at: generation.submitted_at || now,
          failure_category: nil,
          next_attempt_at: nil
        )
      end
    end

    def handle_submission_error(generations, error)
      generations.each { |generation| FailureHandler.call(generation, category: error.category, retryable: error.retryable?) }
      Result.new(status: :provider_error, batch_id: nil, generation_ids: generations.map(&:id))
    end

    def empty
      Result.new(status: :not_due, batch_id: nil, generation_ids: [])
    end
  end
end
