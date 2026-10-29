class SubscriptionBilling
  def self.activate(user, type:, plan:, auto_renew: false)
    user.with_lock do
      subscription = user.subscriptions.find_or_initialize_by(professional_type: type)
      same_period = subscription.persisted? && subscription.status == 'active' && subscription.plan == plan && subscription.renews_at&.future?
      subscription.assign_attributes(plan: plan, status: 'active', auto_renew: auto_renew)
      unless same_period
        subscription.renews_at = 1.month.from_now
        charge(user, plan)
      end
      subscription.save!
      subscription
    end
  end

  def self.renew_due(subscription)
    subscription.user.with_lock do
      subscription.reload
      return unless subscription.status == 'active' && subscription.auto_renew? && subscription.renews_at && subscription.renews_at <= Time.current
      charge(subscription.user, subscription.plan)
      subscription.update!(renews_at: 1.month.from_now)
      Notification.create!(user: subscription.user, title: 'Plano renovado', body: "Plano #{subscription.plan} renovado até #{subscription.renews_at.to_date}", kind: 'subscription', target: 'planos')
    end
  end

  def self.charge(user, plan)
    price = Subscription::PLANS.fetch(plan)
    user.wallet_entries.create!(kind: 'subscription', amount: -price, status: 'paid') if price.positive?
  end
  private_class_method :charge
end

