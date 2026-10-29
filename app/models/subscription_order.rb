class SubscriptionOrder < ApplicationRecord
  belongs_to :user
  validates :plan, inclusion: { in: Subscription::PLANS.keys }
  validates :professional_type, inclusion: { in: ['guide', 'driver'] }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def approve!
    return if status == 'approved'
    SubscriptionBilling.activate(user, type: professional_type, plan: plan, auto_renew: auto_renew)
    update!(status: 'approved', paid_at: Time.current)
  end
end
