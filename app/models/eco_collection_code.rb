class EcoCollectionCode < ApplicationRecord
  belongs_to :eco_collection_point
  belongs_to :issuer, class_name: 'AdminUser'
  belongs_to :claimed_by, class_name: 'User', optional: true
  before_validation(on: :create) { self.code ||= "ECO-#{SecureRandom.hex(8).upcase.scan(/.{4}/).join('-')}" }
  validates :code, presence: true, uniqueness: true
  validates :points, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100000 }
  validates :expires_at, presence: true
  validate do
    errors.add(:expires_at, 'deve estar no futuro, em até um ano') if new_record? && (!expires_at || expires_at <= Time.current || expires_at > 1.year.from_now)
  end
end
