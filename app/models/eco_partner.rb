class EcoPartner < ApplicationRecord
  has_many :eco_rewards, dependent: :restrict_with_error
  validates :name, :city, :address, presence: true, length: { maximum: 255 }
  validates :image_url, length: { maximum: 255 }, allow_blank: true
  validates :image_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
end
