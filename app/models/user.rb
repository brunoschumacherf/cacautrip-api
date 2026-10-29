class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  has_one :guide_profile, dependent: :destroy
  has_one :driver_profile, dependent: :destroy
  has_many :routes, dependent: :destroy
end