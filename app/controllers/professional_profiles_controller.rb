class ProfessionalProfilesController < ApplicationController
  before_action :authenticate_user!, only: [:create_guide, :create_driver, :mine, :commission]

  COMMON = [:region, :price, :available, :accessible, :services, :document_reference, :description, :image_url].freeze

  def commission
    render json: CommissionQuote.call(params[:amount].presence || 0)
  rescue ArgumentError
    render_error('Informe um valor válido para consultar a comissão')
  end

  def create_guide
    save_profile('guide', COMMON + [:specialization, :languages])
  end

  def create_driver
    save_profile('driver', COMMON + [:vehicle_model, :license_plate, :capacity])
  end

  def index_guides
    list(GuideProfile)
  end

  def index_drivers
    list(DriverProfile)
  end

  def show
    klass = { 'guide' => GuideProfile, 'driver' => DriverProfile }[params[:kind]]
    return render_error('Serviço inválido', :not_found) unless klass
    profile = klass.joins(:user).where(users: { gov_verified: true, suspended: false }, moderation_status: 'published').find(params[:id])
    render json: ProfessionalDirectory.serialize(profile)
  end

  def mine
    profiles = [@current_user.guide_profile, @current_user.driver_profile].compact
    payload = profiles.map do |profile|
      type = profile.is_a?(GuideProfile) ? 'Guia' : 'Motorista'
      bookings = Booking.where(service_type: type, service_id: profile.id)
      ProfessionalDirectory.serialize(profile, private_fields: true).merge(
        type: type, bookings_count: bookings.count, completed_count: bookings.where(status: 'completed').count,
        gross: bookings.where(payment_status: 'approved').sum(:total_amount),
        net: bookings.where(payment_status: 'approved').sum(:professional_amount))
    end
    render json: payload
  end

  private

  def list(klass)
    profiles = klass.joins(:user).where(users: { gov_verified: true, suspended: false }, moderation_status: 'published').includes(:user)
    profiles = profiles.where(available: true) if params[:available] == 'true'
    profiles = profiles.where(accessible: true) if params[:accessible] == 'true'
    profiles = profiles.where('price <= ?', params[:max_price].to_f) if params[:max_price].present?
    profiles = profiles.where('capacity >= ?', params[:people].to_i) if klass == DriverProfile && params[:people].present?
    data = profiles.map { |profile| ProfessionalDirectory.serialize(profile) }
    [:q, :region, :specialization, :services].each do |filter|
      next if params[filter].blank?
      term = params[filter].to_s.downcase
      data.select! { |item| [item[:name], item['region'], item['specialization'], item['services'], item['vehicle_model'], item['description']].compact.join(' ').downcase.include?(term) }
    end
    data.select! { |item| item[:rating].to_f >= params[:min_rating].to_f } if params[:min_rating].present?
    data.sort_by! { |item| [-({ 'premium' => 2, 'featured' => 1 }[item[:plan]] || 0), -item[:rating].to_f, item['price'].to_f] }
    render json: data
  end

  def save_profile(kind, fields)
    return render_error('Autentique sua conta no Gov.br pelo perfil antes de se cadastrar.', :forbidden) unless @current_user.gov_verified?
    profile = @current_user.public_send("#{kind}_profile") || @current_user.public_send("build_#{kind}_profile")
    profile.assign_attributes(params.permit(*fields, availability: []))
    profile.moderation_status = 'pending' if profile.new_record? || profile.document_reference_changed?
    profile.save!
    render json: { message: 'Perfil salvo. Cadastros e alterações de documento aguardam aprovação administrativa.', profile: ProfessionalDirectory.serialize(profile, private_fields: true) }
  end
end
