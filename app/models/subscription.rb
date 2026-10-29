class Subscription < ApplicationRecord
  belongs_to :user
  PLANS = { 'basic' => 0, 'featured' => 29.90, 'premium' => 59.90 }.freeze
  validates :plan, inclusion: { in: PLANS.keys }
  validates :professional_type, inclusion: { in: ['guide', 'driver'] }
  validates :status, inclusion: { in: ['active', 'cancelled'] }
end
