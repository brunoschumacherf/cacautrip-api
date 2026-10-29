class Route < ApplicationRecord
  belongs_to :user
  has_many :bookings, dependent: :nullify
  validates :title, :destination, presence: true
end
