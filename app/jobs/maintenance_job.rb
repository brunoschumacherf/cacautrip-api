class MaintenanceJob < ApplicationJob
  queue_as :default

  def perform
    GoogleAuthFlow.where('created_at < ?', 1.day.ago).delete_all
    User.where(id: Booking.joins(:eco_redemption).where(payment_status: 'pending').where('hold_expires_at <= ?', Time.current).select(:user_id)).find_each do |user|
      EcoCheckout.release_expired_holds!(user)
    end
    Subscription.where(status: 'active', auto_renew: true).where('renews_at <= ?', Time.current).find_each do |subscription|
      begin
        SubscriptionBilling.renew_due(subscription)
      rescue StandardError => error
        Rails.logger.error("maintenance subscription_id=#{subscription.id} error_class=#{error.class.name}")
      end
    end
  end
end
