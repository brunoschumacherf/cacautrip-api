class DriverProfile < ApplicationRecord
  belongs_to :user
  validates :vehicle_model, :license_plate, :document_reference, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :moderation_status, inclusion: { in: ['pending', 'published', 'rejected', 'hidden'] }
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 60 }
end
