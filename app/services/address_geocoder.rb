require 'net/http'
require 'json'
require 'digest'

# Photon compatível; cache persistente e limite global entre processos pelo PostgreSQL.
# Nenhum endereço de cliente/reserva ou posição do aparelho é enviado ao provedor.
class AddressGeocoder
  def self.normalize(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').strip
  end

  def self.resolve(query, city:, area: false)
    return {} if query.blank? || city.blank?
    fingerprint = Digest::SHA256.hexdigest([query, city, area].join('|'))
    GeocodedAddress.transaction do
      GeocodedAddress.connection.execute('SELECT pg_advisory_xact_lock(78103001)')
      cached = GeocodedAddress.find_or_create_by!(fingerprint: fingerprint) { |item| item.query = query }
      return cached.result if cached.status == 'resolved'
      return {} if %w[not_found failed].include?(cached.status) && cached.updated_at > 1.day.ago
      wait = 1.1 - (Time.current - (GeocodedAddress.maximum(:requested_at) || 1.minute.ago))
      sleep(wait) if wait.positive?
      cached.update!(requested_at: Time.current)
      result = fetch(query, city: city, area: area)
      cached.update!(status: result.empty? ? 'not_found' : 'resolved', result: result)
      result
    rescue StandardError => error
      cached&.update!(status: 'failed', result: {})
      Rails.logger.warn("geocoding failure=#{error.class.name}")
      {}
    end
  end

  def self.fetch(query, city:, area:)
    uri = URI(ENV.fetch('GEOCODING_URL', 'https://photon.komoot.io/api/'))
    raise 'O geocodificador exige HTTPS' unless uri.scheme == 'https'
    uri.query = URI.encode_www_form(q: query, limit: 5, countrycode: 'BR')
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Cacautrip/1.0 (public tourism locations)'
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) { |http| http.request(request) }
    raise "Geocodificador HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    feature = Array(JSON.parse(response.body)['features']).find do |item|
      props = item['properties'] || {}
      names = [props['city'], props['county'], (props['name'] if area)].compact.map { |name| normalize(name) }
      same_city = names.any? { |name| name == normalize(city) || name.include?(normalize(city)) }
      locality = %w[city town village suburb municipality county state country].include?(props['osm_value'])
      same_city && (area || !locality)
    end
    return {} unless feature
    lon, lat = feature.dig('geometry', 'coordinates')
    lat, lon = Float(lat), Float(lon)
    return {} unless lat.finite? && lon.finite? && lat.between?(-34, 6) && lon.between?(-74, -34)
    props = feature['properties'] || {}
    { 'latitude' => lat, 'longitude' => lon, 'approximate' => area || (props['street'].present? && props['housenumber'].blank?) || props['osm_key'] == 'highway' }
  end
  private_class_method :fetch
end
