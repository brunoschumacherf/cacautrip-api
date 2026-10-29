class Report < ApplicationRecord
  belongs_to :user
  validates :reason, presence: true, length: { maximum: 4000 }
  validates :subject_type, inclusion: { in: ['Review', 'User', 'Message'] }
  validates :status, inclusion: { in: ['open', 'resolved', 'dismissed'] }
end
