class Conversation < ApplicationRecord
  belongs_to :tourist, class_name: 'User'
  belongs_to :guide, class_name: 'User', optional: true
  belongs_to :driver, class_name: 'User', optional: true
  has_many :messages, dependent: :destroy
  belongs_to :booking, optional: true
  validate :one_professional

  def participant?(user)
    [tourist_id, guide_id, driver_id].compact.include?(user.id)
  end

  def one_professional
    errors.add(:base, 'Informe um guia ou motorista') unless guide_id.present? ^ driver_id.present?
  end
end
