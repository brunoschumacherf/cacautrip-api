class MaintenanceJob < ApplicationJob
  queue_as :default

  def perform
    GoogleAuthFlow.where('created_at < ?', 1.day.ago).delete_all
    Subscription.where(status: 'active', auto_renew: true).where('renews_at <= ?', Time.current).find_each do |subscription|
      begin
        SubscriptionBilling.renew_due(subscription)
      rescue StandardError => error
        Rails.logger.error("maintenance subscription_id=#{subscription.id} error_class=#{error.class.name}")
      end
    end
  end
end
