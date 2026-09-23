# frozen_string_literal: true

require "digest"
require "json"

module AiSummary
  class SourceBuilder
    Result = Data.define(:text, :message_ids, :message_count, :last_message, :fingerprint, :estimated_input_tokens)

    def self.call(topic, message_ids: nil)
      new(topic, message_ids:).call
    end

    def initialize(topic, message_ids: nil)
      @topic = topic
      @message_ids = message_ids
    end

    def call
      relation = topic.messages.sent
      relation = relation.where(id: message_ids) if message_ids
      messages = relation
                      .preload(:attachments, :mailing_lists, sender_person: :default_alias, sender: {})
                      .order(:created_at, :id).to_a
      payload = messages.each_with_index.map { |message, index| message_payload(message, index + 1) }
      serialized = JSON.generate(
        "source_format" => "v1",
        "topic_id" => topic.id,
        "topic_title" => topic.title,
        "messages" => payload
      )

      Result.new(
        text: serialized,
        message_ids: messages.map(&:id),
        message_count: messages.size,
        last_message: messages.last,
        fingerprint: Digest::SHA256.hexdigest(serialized),
        estimated_input_tokens: (serialized.bytesize.to_f / Eligibility::CHARS_PER_TOKEN).ceil
      )
    end

    private

    attr_reader :topic, :message_ids

    def message_payload(message, number)
      sender = message.sender_display_alias
      {
        "message_id" => message.id,
        "message_number" => number,
        "subject" => message.subject,
        "sent_at" => message.created_at&.iso8601,
        "sender" => sender&.name,
        "reply_to_message_id" => message.reply_to_id,
        "mailing_lists" => message.mailing_lists.map(&:identifier).sort,
        "attachments" => message.attachments.sort_by(&:id).map { |attachment| attachment_payload(attachment) },
        "untrusted_archived_content" => MessageNormalizer.call(message.body)
      }
    end

    def attachment_payload(attachment)
      {
        "file_name" => attachment.file_name,
        "content_type" => attachment.content_type,
        "encoded_size_bytes" => attachment.body&.bytesize
      }.compact
    end
  end
end
