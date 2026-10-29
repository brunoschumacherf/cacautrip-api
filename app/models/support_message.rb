class SupportMessage < ApplicationRecord
  belongs_to :support_ticket
  belongs_to :admin_user, optional: true
  validates :role, inclusion: { in: %w[user assistant staff system] }
  validates :content, presence: true, length: { maximum: 8000 }

  def public_message
    as_json(only: [:id, :role, :content, :sender_name, :created_at])
  end
end
