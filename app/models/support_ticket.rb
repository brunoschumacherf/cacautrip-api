class SupportTicket < ApplicationRecord
  belongs_to :user
  validates :message, presence: true, length: { maximum: 4000 }
  validates :status, inclusion: { in: ['open', 'answered', 'closed'] }
end
