class SubscriptionOrdersController < ApplicationController
  before_action :authenticate_user!

  def create
    type, plan = params.values_at(:professional_type, :plan)
    return render_error('Plano inválido') unless ['guide', 'driver'].include?(type) && Subscription::PLANS.key?(plan)
    return render_error('Cadastre seu perfil profissional') unless @current_user.public_send("#{type}_profile")
    order = SubscriptionOrder.create!(user: @current_user, professional_type: type, plan: plan,
      amount: Subscription::PLANS.fetch(plan), auto_renew: ActiveModel::Type::Boolean.new.cast(params[:auto_renew]) || false)
    render json: order, status: :created
  end

  def pay
    order = SubscriptionOrder.where(user: @current_user).find(params[:id])
    order.with_lock do
      return render json: order if order.status == 'approved'
      method = params[:payment_method]
      return render_error('Selecione Pix ou cartão') unless ['pix', 'credit_card'].include?(method)
      order.update!(payment_method: method, payment_polls: order.payment_method == method ? order.payment_polls : 0)
      order.approve! if method == 'credit_card' || order.amount.zero?
    end
    render json: order
  end

  def payment_status
    order = SubscriptionOrder.where(user: @current_user).find(params[:id])
    order.with_lock do
      if order.status == 'pending' && order.payment_method == 'pix'
        order.update!(payment_polls: order.payment_polls + 1)
        order.approve! if order.payment_polls >= 4
      end
    end
    render json: order
  end
end
