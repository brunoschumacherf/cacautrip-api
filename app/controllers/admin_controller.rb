class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  RESOURCES = { 'users' => User, 'guides' => GuideProfile, 'drivers' => DriverProfile, 'destinations' => Destination,
    'emergency_points' => EmergencyPoint, 'alerts' => Alert, 'reviews' => Review, 'reports' => Report,
    'tickets' => SupportTicket, 'subscriptions' => Subscription, 'bookings' => Booking, 'messages' => Message, 'trails' => Trail }.freeze
  FIELDS = {
    'users' => [:name, :suspended],
    'guides' => [:moderation_status, :verified_documents, :available],
    'drivers' => [:moderation_status, :verified_cnh, :available],
    'destinations' => [:name, :category, :city, :description, :image_url, :latitude, :longitude, :price, :duration_minutes, :opening_hours, :rules, :accessible, :guide_required, :active, :best_time, :provider_id],
    'emergency_points' => [:name, :category, :phone, :address, :latitude, :longitude],
    'alerts' => [:title, :body, :kind, :region, :source_url, :expires_at],
    'reviews' => [:hidden], 'messages' => [:hidden], 'reports' => [:status], 'tickets' => [:status, :reply], 'subscriptions' => [:status], 'trails' => [:status]
  }.freeze

  def dashboard
    render json: { users: User.count, bookings: Booking.count, completed: Booking.where(status: 'completed').count,
      gross: Booking.where(payment_status: 'approved').sum(Arel.sql('total_amount - discount_amount')), fees: Booking.where(payment_status: 'approved').sum(:fee_amount),
      eco_discounts: Booking.where(payment_status: 'approved').sum(:discount_amount),
      open_reports: Report.where(status: 'open').count, open_tickets: SupportTicket.where(status: 'open').count,
      commission: PlatformSetting.commission, visits_by_destination: Route.group(:destination).count,
      bookings_by_status: Booking.group(:status).count, signups_by_day: User.group('DATE(created_at)').count,
      payments_mock: true, analytics: 'Contagens agregadas, sem rastreamento individual de localização' }
  end

  def index
    klass = RESOURCES[params[:resource]]
    return render_error('Recurso inválido', :not_found) unless klass
    records = klass.order(created_at: :desc).limit(200)
    render json: records.map { |record| serialize(record) }
  end

  def create
    resource = params[:resource]
    return render_error('Criação não permitida') unless ['destinations', 'emergency_points', 'alerts'].include?(resource)
    record = RESOURCES.fetch(resource).create!(params.require(:record).permit(*FIELDS.fetch(resource)))
    render json: serialize(record), status: :created
  end

  def update
    resource = params[:resource]
    return render_error('Recurso não editável') unless FIELDS.key?(resource)
    record = RESOURCES.fetch(resource).find(params[:id])
    attributes = params.require(:record).permit(*FIELDS.fetch(resource))
    if ['guides', 'drivers'].include?(resource) && attributes[:moderation_status] == 'published' && !record.user.gov_verified?
      return render_error('A conta deve autenticar Gov.br antes da aprovação')
    end
    if ['guides', 'drivers'].include?(resource) && attributes[:moderation_status] == 'published' && record.document_reference.blank?
      return render_error('Solicite o preenchimento da referência do documento profissional')
    end
    return render_error('Você não pode suspender sua própria conta') if resource == 'users' && record.id == @current_user.id && ActiveModel::Type::Boolean.new.cast(attributes[:suspended])
    record.update!(attributes)
    if resource == 'tickets' && record.reply.present?
      Notification.create!(user: record.user, title: 'Resposta do suporte', body: record.reply, kind: 'support', target: 'suporte')
    elsif ['guides', 'drivers'].include?(resource)
      Notification.create!(user: record.user, title: 'Perfil profissional atualizado', body: record.moderation_status, kind: 'profile', target: 'perfil')
    end
    render json: serialize(record)
  end

  def commission
    rate = BigDecimal(params[:rate].to_s) rescue nil
    return render_error('Informe uma taxa entre 0 e 1') unless rate && rate.between?(0, 1)
    setting = PlatformSetting.find_or_initialize_by(key: 'commission')
    setting.update!(value: { rate: rate.to_f })
    render json: setting
  end

  private

  def serialize(record)
    return record.public_profile.merge(suspended: record.suspended) if record.is_a?(User)
    return record.details if record.is_a?(Booking)
    record.as_json
  end
end
