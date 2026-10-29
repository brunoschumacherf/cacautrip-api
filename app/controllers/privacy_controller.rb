class PrivacyController < ApplicationController
  before_action :authenticate_user!

  def export
    render json: { exported_at: Time.current, profile: @current_user.public_profile,
      routes: @current_user.routes, bookings: @current_user.bookings.map(&:details),
      wallet: @current_user.wallet_entries, subscriptions: @current_user.subscriptions,
      eco_vouchers: @current_user.eco_redemptions.map(&:public_voucher), eco_points_history: @current_user.eco_point_entries.as_json(only: [:amount, :description, :created_at]),
      reviews: Review.where(user: @current_user), tickets: @current_user.support_tickets.map { |ticket| ticket.summary.merge(messages: ticket.support_messages.order(:id).map(&:public_message)) } }
  end

  def request_deletion
    ticket = @current_user.support_tickets.create!(status: 'open', message: 'Solicitação de exclusão/anônimização de dados pessoais. Confirmar titularidade, obrigações de retenção e pendências financeiras antes de processar.')
    render json: { message: 'Solicitação registrada para análise. Acompanhe a resposta no suporte.', ticket_id: ticket.id }, status: :created
  end
end
