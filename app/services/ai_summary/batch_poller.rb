# frozen_string_literal: true

require "json"

module AiSummary
  class BatchPoller
    IN_PROGRESS = %w[validating in_progress finalizing cancelling].freeze
    TERMINAL = %w[completed failed expired cancelled].freeze

    def self.call(client: OpenAi::Client.new)
      new(client:).call
    end

    def initialize(client:)
      @client = client
    end

    def call
      TopicSummaryGeneration.where(state: %w[submitted processing])
                            .where.not(provider_batch_id: nil)
                            .distinct.pluck(:provider_batch_id).each do |batch_id|
        poll(batch_id)
      end
    end

    private

    attr_reader :client

    def poll(batch_id)
      batch = client.retrieve_batch(batch_id)
      status = batch.fetch("status")
      generations = TopicSummaryGeneration.where(provider_batch_id: batch_id, state: %w[submitted processing])

      if IN_PROGRESS.include?(status)
        generations.update_all(state: "processing", processing_at: Time.current, updated_at: Time.current)
      elsif TERMINAL.include?(status)
        process_terminal(batch, generations.to_a)
      end
    rescue OpenAi::Client::Error => e
      generations&.each { |generation| FailureHandler.call(generation, category: e.category, retryable: e.retryable?) }
    end

    def process_terminal(batch, generations)
      items = read_items(batch["output_file_id"]) + read_items(batch["error_file_id"])
      by_custom_id = items.index_by { |item| item["custom_id"] }
      generations.each do |generation|
        item = by_custom_id[generation.provider_item_id]
        if item
          ResultProcessor.call(generation, item)
        else
          FailureHandler.call(generation, category: "batch_#{batch.fetch('status')}", retryable: true)
        end
      end
    end

    def read_items(file_id)
      return [] if file_id.blank?

      client.retrieve_file_content(file_id).lines.filter_map do |line|
        JSON.parse(line) if line.present?
      end
    end
  end
end
