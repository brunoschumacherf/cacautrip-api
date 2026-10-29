class EcoRedemption < ApplicationRecord
  belongs_to :user
  belongs_to :eco_reward
  belongs_to :booking, optional: true
  belongs_to :validated_by, class_name: 'AdminUser', optional: true
  before_validation(on: :create) { self.code ||= "VERDE-#{SecureRandom.hex(8).upcase.scan(/.{4}/).join('-')}" }
  validates :code, uniqueness: true, presence: true
  validates :request_key, presence: true, length: { maximum: 100 }
  validates :points_cost, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: %w[available reserved used] }

  def discount_for(amount)
    gross = BigDecimal(amount.to_s)
    return BigDecimal('0') if gross < BigDecimal(benefit.fetch('minimum_amount', 0).to_s)
    value = BigDecimal(benefit.fetch('discount_value').to_s)
    value = gross * value / 100 if benefit['discount_type'] == 'percent'
    value = [value, BigDecimal(benefit['maximum_discount'].to_s)].min if benefit['maximum_discount'].present?
    [value.round(2), gross].min
  end

  def public_voucher
    as_json(only: [:id, :code, :status, :benefit, :points_cost, :expires_at, :used_at, :booking_id]).merge(expired: expires_at <= Time.current)
  end
end
