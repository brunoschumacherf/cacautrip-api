class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: { plans: Subscription::PLANS, subscriptions: @current_user.subscriptions.order(:professional_type), mock: true }
  end

  def create
    type, plan = params.values_at(:professional_type, :plan)
    return render_error('Plano inválido') unless Subscription::PLANS.key?(plan) && ['guide', 'driver'].include?(type)
    return render_error('Cadastre o perfil profissional primeiro') unless @current_user.public_send("#{type}_profile")
    return render_error('Escolha a forma de pagamento para ativar este plano') if Subscription::PLANS.fetch(plan).positive?
    renewal = ActiveModel::Type::Boolean.new.cast(params[:auto_renew]) || false
    subscription = SubscriptionBilling.activate(@current_user, type: type, plan: plan, auto_renew: renewal)
    render json: { subscription: subscription, message: 'Plano atualizado.' }
  end

  def update
    subscription = @current_user.subscriptions.find(params[:id])
    subscription.update!(auto_renew: ActiveModel::Type::Boolean.new.cast(params[:auto_renew]))
    render json: subscription
  end

  def destroy
    subscription = @current_user.subscriptions.find(params[:id])
    subscription.update!(status: 'cancelled', auto_renew: false)
    render json: subscription
  end
end
