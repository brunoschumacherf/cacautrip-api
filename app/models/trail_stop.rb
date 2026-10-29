class TrailStop < ApplicationRecord
  include GeocodablePlace
  belongs_to :trail, inverse_of: :stops
  validates :name, :address, presence: true
  validates :name, :address, length: { maximum: 300 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1440 }
  validates :kind, inclusion: { in: ['meeting', 'visit', 'break', 'finish'] }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :coordinate_pair

  private

  def coordinate_pair
    errors.add(:base, 'Preencha latitude e longitude juntas, ou deixe ambas vazias') if latitude.nil? != longitude.nil?
  end
end
