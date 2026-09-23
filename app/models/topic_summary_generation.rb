class TopicSummaryGeneration < ApplicationRecord
  ACTIVE_STATES = %w[queued submitted processing].freeze
  TERMINAL_STATES = %w[completed unsupported terminal_failed cancelled].freeze
  STATES = (ACTIVE_STATES + TERMINAL_STATES).freeze

  belongs_to :topic
  belongs_to :last_message, class_name: "Message", optional: true
  has_one :topic_summary, dependent: :destroy

  enum :state, STATES.index_with(&:itself), validate: true

  scope :active, -> { where(state: ACTIVE_STATES) }
  scope :terminal, -> { where(state: TERMINAL_STATES) }

  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :last_message_belongs_to_topic
  validate :source_message_ids_match_coverage

  def active? = ACTIVE_STATES.include?(state)
  def terminal? = TERMINAL_STATES.include?(state)

  private

  def last_message_belongs_to_topic
    return if last_message.nil? || last_message.topic_id == topic_id

    errors.add(:last_message, "must belong to the generation topic")
  end

  def source_message_ids_match_coverage
    return if source_message_ids.blank? && source_message_count.nil?
    return if source_message_ids.present? && source_message_ids.size == source_message_count

    errors.add(:source_message_ids, "must match the recorded source message count")
  end
end
