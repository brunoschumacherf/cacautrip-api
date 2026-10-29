class CatalogController < ApplicationController
  def highlights
    render json: DestinationHighlights.call(city: params[:city], latitude: params[:latitude], longitude: params[:longitude])
  end
  def show
    render json: Destination.where(active: true).find(params[:id])
  end
  def index
    destinations = Destination.where(active: true)
    destinations = destinations.where(category: params[:category]) if params[:category].present?
    destinations = destinations.where(accessible: true) if params[:accessible] == 'true'
    destinations = destinations.where('price <= ?', params[:budget].to_f) if params[:budget].present?
    if params[:q].present?
      term = "%#{Destination.sanitize_sql_like(params[:q])}%"
      destinations = destinations.where('name ILIKE ? OR city ILIKE ? OR description ILIKE ?', term, term, term)
    end
    destinations = destinations.order(:name, :id)
    paginated = params[:page].present? || params[:per_page].present?
    if paginated
      total = destinations.count
      per_page = (params[:per_page].presence || 6).to_i.clamp(1, 30)
      total_pages = [(total.to_f / per_page).ceil, 1].max
      page = (params[:page].presence || 1).to_i.clamp(1, total_pages)
      pagination = { page: page, per_page: per_page, total: total, total_pages: total_pages,
        has_previous: page > 1, has_next: page < total_pages }
    end
    nearby = params[:latitude].present? && params[:longitude].present?
    destinations = destinations.offset((page - 1) * per_page).limit(per_page) if paginated && !nearby
    result = destinations.as_json
    if nearby
      lat, lon = params.values_at(:latitude, :longitude).map(&:to_f)
      result.each { |item| item['distance_km'] = distance(lat, lon, item['latitude'], item['longitude']) }
      result.sort_by! { |item| item['distance_km'] || Float::INFINITY }
      result = result.slice((page - 1) * per_page, per_page) || [] if paginated
    end
    payload = { destinations: result, alerts: Alert.current.order(created_at: :desc), emergency_points: EmergencyPoint.all }
    payload[:pagination] = pagination if paginated
    render json: payload
  end

  private

  def distance(lat, lon, target_lat, target_lon)
    return unless target_lat && target_lon
    rad = Math::PI / 180
    a = Math.sin((target_lat - lat) * rad / 2)**2 + Math.cos(lat * rad) * Math.cos(target_lat * rad) * Math.sin((target_lon - lon) * rad / 2)**2
    (6371 * 2 * Math.asin(Math.sqrt(a.clamp(0, 1)))).round(1)
  end
end
