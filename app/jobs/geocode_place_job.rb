class GeocodePlaceJob < ApplicationJob
  ALLOWED = %w[EcoCollectionPoint EcoPartner Destination TrailStop EmergencyPoint].freeze
  def perform(type, id)
    return unless ALLOWED.include?(type)
    record = type.constantize.find_by(id: id)
    return unless record && (record.latitude.nil? || record.longitude.nil?)
    queries, city = record.geocoding_queries, record.geocoding_city
    result = {}
    queries.each do |query|
      result = AddressGeocoder.resolve(query, city: city)
      break if result.present?
    end
    return if result.empty?
    record.with_lock do
      return unless record.geocoding_queries == queries && (record.latitude.nil? || record.longitude.nil?)
      record.update_columns(latitude: result.fetch('latitude'), longitude: result.fetch('longitude'),
        geocoding_approximate: result.fetch('approximate'), updated_at: Time.current)
    end
  end
end
