class Review < ApplicationRecord
  belongs_to :booking
  belongs_to :user
  validates :rating, inclusion: { in: 1..5 }
  validates :comment, length: { maximum: 2000 }
  validates :booking_id, uniqueness: true
  validate :completed_by_author

  def completed_by_author
    errors.add(:base, 'Avalie somente sua reserva concluída') unless booking&.user_id == user_id && booking&.status == 'completed'
  end
end
