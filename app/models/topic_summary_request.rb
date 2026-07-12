class TopicSummaryRequest < ApplicationRecord
  KINDS = %w[initiator subscriber].freeze

  belongs_to :topic_summary_generation
  belongs_to :user

  enum :request_kind, KINDS.index_with(&:itself), validate: true

  validates :user_id, uniqueness: { scope: :topic_summary_generation_id }
  validate :initiator_consumes_quota

  private

  def initiator_consumes_quota
    return unless initiator? && quota_consumed_at.nil?

    errors.add(:quota_consumed_at, "must be set for an initiating request")
  end
end
