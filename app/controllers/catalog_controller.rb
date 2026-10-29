class CatalogController < ApplicationController
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
    result = destinations.as_json
    if params[:latitude].present? && params[:longitude].present?
      lat, lon = params.values_at(:latitude, :longitude).map(&:to_f)
      result.each { |item| item['distance_km'] = distance(lat, lon, item['latitude'], item['longitude']) }
      result.sort_by! { |item| item['distance_km'] || Float::INFINITY }
    end
    render json: { destinations: result, alerts: Alert.current.order(created_at: :desc), emergency_points: EmergencyPoint.all }
  end

  private

  def distance(lat, lon, target_lat, target_lon)
    return unless target_lat && target_lon
    rad = Math::PI / 180
    a = Math.sin((target_lat - lat) * rad / 2)**2 + Math.cos(lat * rad) * Math.cos(target_lat * rad) * Math.sin((target_lon - lon) * rad / 2)**2
    (6371 * 2 * Math.asin(Math.sqrt(a.clamp(0, 1)))).round(1)
  end
end
