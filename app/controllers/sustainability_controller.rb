class SustainabilityController < ApplicationController
  before_action :authenticate_user!
  rescue_from EcoProgram::Invalid, EcoCheckout::Invalid do |error|
    render_error(error.message)
  end

  def index
    points = EcoCollectionPoint.available
    rewards = EcoReward.available.includes(:eco_partner)
    if params[:city].present?
      city = params[:city].to_s.strip
      points = points.where('city ILIKE ?', city)
      rewards = rewards.where("scope <> 'partner' OR eco_partner_id IN (SELECT id FROM eco_partners WHERE city ILIKE ?)", city)
    end
    render json: { balance: @current_user.reload.eco_points, cities: EcoCollectionPoint.where(active: true).distinct.order(:city).pluck(:city),
      collection_points: points, rewards: rewards.order(:points_cost, :id).map(&:public_reward),
      vouchers: @current_user.eco_redemptions.order(created_at: :desc).limit(100).map(&:public_voucher),
      history: @current_user.eco_point_entries.order(id: :desc).limit(50).as_json(only: [:id, :amount, :description, :created_at]) }
  end

  def overview
    render json: { balance: @current_user.eco_points, collection_points_count: EcoCollectionPoint.where(active: true).count,
      rewards: EcoReward.available.includes(:eco_partner).order(:points_cost, :id).limit(3).map(&:public_reward) }
  end

  def claim
    return render_error('Aguarde um minuto antes de tentar outro código.', :too_many_requests) unless AuthenticationThrottle.allow?("eco-claim:#{@current_user.id}:#{request.remote_ip}")
    entry = EcoProgram.claim(@current_user, params[:collection_code])
    message = entry.saved_change_to_claimed_at? ? "Código confirmado: #{entry.points} pontos pela coleta." : 'Este código já foi creditado na sua conta. Confira seu extrato.'
    render json: { balance: @current_user.reload.eco_points, message: message }
  end

  def redeem
    voucher = EcoProgram.redeem(@current_user, params[:reward_id], params[:request_key])
    render json: { voucher: voucher.public_voucher, balance: @current_user.reload.eco_points }, status: :created
  end

  def discounts
    booking = @current_user.bookings.find(params[:booking_id])
    EcoCheckout.release_expired_holds!(@current_user)
    vouchers = EcoCheckout.available_for(booking).to_a.select { |voucher| voucher.discount_for(booking.total_amount).positive? }
    render json: { balance: @current_user.reload.eco_points,
      vouchers: vouchers.map { |voucher| voucher.public_voucher.merge(discount: voucher.discount_for(booking.total_amount).to_f) },
      rewards: EcoReward.available.where(scope: EcoCheckout.scope_for(booking)).order(:points_cost, :id).map(&:public_reward) }
  end
end
