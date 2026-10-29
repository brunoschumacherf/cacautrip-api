class User < ApplicationRecord
  has_secure_password
  before_validation { self.email = email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true

  has_one :guide_profile, dependent: :destroy
  has_one :driver_profile, dependent: :destroy
  has_many :routes, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :wallet_entries
  has_many :subscriptions
  has_many :support_tickets
  validates :active_role, inclusion: { in: ['tourist', 'guide', 'driver'] }

  def public_profile
    as_json(only: [:id, :name, :email, :gov_verified, :active_role, :preferences, :admin]).merge(
      guide_profile: guide_profile, driver_profile: driver_profile,
      roles: ['tourist', ('guide' if guide_profile), ('driver' if driver_profile)].compact)
  end
end
