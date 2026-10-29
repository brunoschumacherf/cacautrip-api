class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true

  has_one :guide_profile, dependent: :destroy
  has_one :driver_profile, dependent: :destroy
  has_many :routes, dependent: :destroy
end