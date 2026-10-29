class EcoCollectionPoint < ApplicationRecord
  include GeocodablePlace
  has_many :eco_collection_codes, dependent: :restrict_with_error
  validates :name, :city, :address, presence: true, length: { maximum: 255 }
  validates :materials, :opening_hours, :image_url, length: { maximum: 255 }, allow_blank: true
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validates :image_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  validate do
    if latitude.present? != longitude.present?
      errors.add(:base, 'Informe latitude e longitude juntas para exibir o ponto no mapa, ou deixe ambas vazias.')
    end
  end
  scope :available, -> { where(active: true).order(:city, :name, :id) }
end
