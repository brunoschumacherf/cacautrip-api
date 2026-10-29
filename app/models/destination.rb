class Destination < ApplicationRecord
  belongs_to :provider, class_name: 'User', optional: true
  validates :name, :category, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
end
