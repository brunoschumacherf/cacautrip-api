class TrailsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]

  def index
    trails = Trail.visible.includes(:stops, :departures, guide_profile: :user)
    trails = trails.where(guide_profile_id: params[:guide_id]) if params[:guide_id].present?
    trails = trails.where(difficulty: params[:difficulty]) if params[:difficulty].present?
    trails = trails.where(accessible: true) if params[:accessible] == 'true'
    trails = trails.where('trails.price <= ?', params[:max_price].to_f) if params[:max_price].present?
    if params[:q].present?
      term = "%#{Trail.sanitize_sql_like(params[:q].to_s)}%"
      trails = trails.where('trails.title ILIKE ? OR trails.region ILIKE ? OR trails.description ILIKE ?', term, term, term)
    end
    if params[:date].present?
      day = Date.iso8601(params[:date])
      trails = trails.where(id: TrailDeparture.where(status: 'scheduled', starts_at: day.in_time_zone.all_day).select(:trail_id))
    end
    render json: trails.order(created_at: :desc).limit(100).map { |trail| trail.serialize }
  rescue Date::Error
    render_error('Informe a data no formato AAAA-MM-DD')
  end

  def show
    render json: Trail.visible.find(params[:id]).serialize
  end

  def mine
    render json: owned.order(created_at: :desc).map { |trail| trail.serialize(owner: true) }
  end

  def edit
    render json: owned.find(params[:id]).serialize(owner: true)
  end

  def create
    return render_error('Cadastre seu perfil de guia primeiro', :forbidden) unless @current_user.guide_profile
    trail = @current_user.guide_profile.trails.new(trail_params)
    trail.save!
    render json: trail.serialize(owner: true), status: :created
  end

  def update
    trail = owned.find(params[:id])
    attributes = trail_params
    attributes[:status] = 'hidden' if trail.status == 'hidden'
    trail.update!(attributes)
    render json: trail.serialize(owner: true)
  end

  def destroy
    trail = owned.find(params[:id])
    trail.update!(status: 'archived')
    render json: trail.serialize(owner: true)
  end

  def duplicate
    original = owned.find(params[:id])
    copy = original.dup
    copy.title = "#{original.title.truncate(125)} (cópia)"
    copy.status = 'draft'
    original.stops.each { |stop| copy.stops.build(stop.attributes.except('id', 'trail_id', 'created_at', 'updated_at')) }
    copy.save!
    render json: copy.serialize(owner: true), status: :created
  end

  private

  def owned
    Trail.joins(:guide_profile).where(guide_profiles: { user_id: @current_user.id })
  end

  def trail_params
    attributes = params.require(:trail).permit(:title, :description, :region, :image_url, :difficulty, :route_mode,
      :duration_minutes, :distance_km, :price, :price_mode, :minimum_age, :accessible, :included, :not_included,
      :what_to_bring, :safety_notes, :cancellation_policy, :status,
      stops_attributes: [:id, :name, :address, :description, :kind, :position, :duration_minutes, :latitude, :longitude, :optional, :_destroy])
    raise ActionController::BadRequest, 'Status inválido' if attributes[:status].present? && !['draft', 'published', 'archived'].include?(attributes[:status])
    attributes
  end
end
