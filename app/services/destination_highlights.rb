require 'net/http'
require 'json'
require 'digest'
require 'cgi'

# As imagens externas ilustram a cidade, sem atribuí-las a um destino diferente.
# Não envia coordenadas de usuários ao Wikimedia nem altera o catálogo.
class DestinationHighlights
  def self.call(city: nil, latitude: nil, longitude: nil)
    cities = Destination.where(active: true).where.not(city: [nil, '']).distinct.order(:city).pluck(:city)
    requested = city.to_s.strip.first(100)
    selected = cities.find { |item| I18n.transliterate(item).casecmp?(I18n.transliterate(requested)) }
    if selected.nil? && latitude.present? && longitude.present?
      lat, lon = Float(latitude, exception: false), Float(longitude, exception: false)
      if lat && lon && lat.finite? && lon.finite? && lat.abs <= 90 && lon.abs <= 180
        points = Destination.where(active: true).where.not(latitude: nil, longitude: nil).pluck(:city, :latitude, :longitude)
        selected = points.min_by { |_, y, x| (y - lat)**2 + ((x - lon) * Math.cos(lat * Math::PI / 180))**2 }&.first
      end
    end
    selected ||= cities.find { |item| item == 'Ilhéus' } || cities.first
    return { city: nil, cities: [], banners: [] } unless selected

    local = Destination.where(active: true, city: selected).where.not(image_url: [nil, '']).order(:name).limit(6).filter_map do |place|
      next unless place.image_url.to_s.start_with?('https://')
      { id: "destination:#{place.id}", destination_id: place.id, name: place.name, city: selected,
        category: place.category, image_url: place.image_url, source: 'catalog' }
    end
    cache_key = "city-banners:v1:#{Digest::SHA256.hexdigest(selected)}"
    external = Rails.cache.read(cache_key)
    if external.nil?
      external = commons_images(selected)
      Rails.cache.write(cache_key, external, expires_in: external.empty? ? 15.minutes : 6.hours)
    end
    { city: selected, cities: cities, banners: (local + external).uniq { |item| item[:image_url] }.first(6) }
  rescue StandardError => error
    Rails.logger.warn("DestinationHighlights: #{error.class}")
    { city: selected, cities: cities || [], banners: local || [] }
  end

  def self.commons_images(city)
    uri = URI('https://commons.wikimedia.org/w/api.php')
    safe_city = city.gsub(/["\\]/, '')
    uri.query = URI.encode_www_form(action: 'query', format: 'json', formatversion: 2,
      generator: 'search', gsrnamespace: 6, gsrlimit: 20,
      gsrsearch: "\"#{safe_city}\" (praia OR beach OR igreja OR cathedral OR paisagem OR landmark)",
      prop: 'imageinfo', iiprop: 'url|extmetadata|size|mime', iiurlwidth: 1280,
      iiextmetadatafilter: 'Artist|LicenseShortName|LicenseUrl|ImageDescription|Restrictions')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 5) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = ENV.fetch('WIKIMEDIA_USER_AGENT', 'Cacautrip/1.0 (https://cacautrip-api.onrender.com; city-photo-banners)')
      request['Accept'] = 'application/json'
      http.request(request)
    end
    return [] unless response.is_a?(Net::HTTPSuccess) && response.body.bytesize < 2_000_000
    Array(JSON.parse(response.body).dig('query', 'pages')).sort_by { |page| page['index'] || 100 }.filter_map do |page|
      image = page.fetch('imageinfo', []).first || {}
      metadata = image['extmetadata'] || {}
      next unless %w[image/jpeg image/png image/webp].include?(image['mime'])
      next unless image['width'].to_i >= 800 && image['width'].to_i > image['height'].to_i
      license = plain(metadata.dig('LicenseShortName', 'value'))
      artist = plain(metadata.dig('Artist', 'value'))
      next if license.blank? || artist.blank? || metadata.dig('Restrictions', 'value').present?
      url = image['thumburl'] || image['url']
      source = image['descriptionurl']
      next unless url.to_s.start_with?('https://upload.wikimedia.org/') && source.to_s.start_with?('https://commons.wikimedia.org/')
      { id: "commons:#{page['pageid']}", destination_id: nil, name: city, city: city,
        caption: plain(metadata.dig('ImageDescription', 'value')).truncate(160), image_url: url,
        source: 'wikimedia', source_url: source, author: artist.truncate(140), license: license,
        license_url: metadata.dig('LicenseUrl', 'value').to_s.start_with?('https://') ? metadata.dig('LicenseUrl', 'value') : nil }
    end.first(6)
  rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    []
  end

  def self.plain(value)
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(value.to_s)).squish
  end
end
