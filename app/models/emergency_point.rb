class EmergencyPoint < ApplicationRecord
  include GeocodablePlace
  validates :name, presence: true
end
