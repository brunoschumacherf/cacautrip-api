module Backoffice
  class DashboardController < BaseController
    def index
      @metrics = { 'Usuários cadastrados' => User.count, 'Reservas' => Booking.count,
        'Perfis aguardando análise' => GuideProfile.where(moderation_status: 'pending').count + DriverProfile.where(moderation_status: 'pending').count,
        'Chamados abertos' => SupportTicket.where(status: 'open').count, 'Denúncias abertas' => Report.where(status: 'open').count,
        'Falhas em aberto' => SystemIncident.where.not(status: 'resolved').count }
      @tickets = SupportTicket.where(status: 'open').order(created_at: :desc).limit(6)
      @incidents = SystemIncident.where.not(status: 'resolved').order(created_at: :desc).limit(6)
      if current_admin_user.admin?
        @gross = Booking.where(payment_status: 'approved').sum(:total_amount)
        @fees = Booking.where(payment_status: 'approved').sum(:fee_amount)
      end
    end
  end
end
