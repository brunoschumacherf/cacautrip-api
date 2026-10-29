class PlatformSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.commission
    rate = find_by(key: 'commission')&.value&.fetch('rate', 0.1) || 0.1
    BigDecimal(rate.to_s).clamp(0, 1)
  end
end
