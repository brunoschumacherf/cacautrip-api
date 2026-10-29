class SupportTicket < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_staff, class_name: 'AdminUser', optional: true
  has_many :support_messages, dependent: :destroy
  validates :message, presence: true, length: { maximum: 4000 }
  validates :status, inclusion: { in: %w[ai open answered closed] }
  after_create :preserve_initial_message
  before_create { self.human_requested_at ||= Time.current if status != 'ai' }
  scope :human_queue, -> { where.not(human_requested_at: nil) }

  def summary
    as_json(only: [:id, :status, :created_at, :updated_at, :human_requested_at]).merge(
      subject: message.truncate(100), assigned_name: assigned_staff&.name,
      ai_responding: ai_request_id.present? && ai_started_at.present? && ai_started_at > 90.seconds.ago)
  end

  private

  def preserve_initial_message
    support_messages.create!(role: 'user', content: message)
    support_messages.create!(role: 'staff', sender_name: 'Equipe de suporte', content: reply) if reply.present?
  end
end
