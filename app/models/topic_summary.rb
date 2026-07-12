class TopicSummary < ApplicationRecord
  belongs_to :topic_summary_generation
  belongs_to :topic
  belongs_to :last_message, class_name: "Message"
  has_many :activities, as: :subject, dependent: :destroy

  scope :visible, -> { where(removed_at: nil) }
  scope :current, -> { visible.where(current: true) }

  validates :source_message_count, numericality: { only_integer: true, greater_than: 0 }
  validates :source_fingerprint, :provider, :model, :prompt_version, :schema_version, presence: true
  validates :topic_summary_generation_id, uniqueness: true
  validates :source_fingerprint, uniqueness: { scope: :topic_id }
  validate :last_message_belongs_to_topic
  validate :source_message_ids_match_coverage
  after_create_commit :enqueue_ready_notifications

  def removed? = removed_at.present?

  private

  def last_message_belongs_to_topic
    return if last_message.nil? || last_message.topic_id == topic_id

    errors.add(:last_message, "must belong to the summary topic")
  end

  def source_message_ids_match_coverage
    return if source_message_ids.size == source_message_count

    errors.add(:source_message_ids, "must match the recorded source message count")
  end

  def enqueue_ready_notifications
    NotifyTopicSummaryReadyJob.perform_later(id)
  end
end
