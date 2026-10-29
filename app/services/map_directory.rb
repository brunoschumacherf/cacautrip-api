require 'digest'
class MapDirectory
  def initialize(query = '', kinds: [])
    @query = I18n.transliterate(query.to_s).downcase.strip
    @regions = {}
    @kinds = kinds
  end

  def call
    points = []
    Destination.where(active: true).find_each do |place|
      points << point(place, 'destination', category: place.category, address: place.city)
    end
    EcoCollectionPoint.available.each { |place| points << point(place, 'collection') }
    EcoPartner.where(active: true).find_each { |place| points << point(place, 'partner') }
    EmergencyPoint.find_each { |place| points << point(place, 'emergency') }
    Trail.visible.includes(:stops, guide_profile: :user).find_each do |trail|
      first = trail.stops.detect { |stop| stop.latitude && stop.longitude }
      points << { id: "trail:#{trail.id}", kind: 'trail', name: trail.title, category: 'Trilha guiada',
        address: first&.address || trail.region, city: trail.region, latitude: first&.latitude&.to_f,
        longitude: first&.longitude&.to_f, approximate: first&.geocoding_approximate || false }
    end
    [[GuideProfile, 'guide'], [DriverProfile, 'driver']].each do |model, kind|
      next unless @kinds.empty? || @kinds.include?(kind)
      model.joins(:user).where(available: true, moderation_status: 'published', users: { gov_verified: true, suspended: false }).includes(:user).find_each do |profile|
        city = profile.region.to_s.split(/[,;\/]/).first.to_s.strip
        location = region(city)
        points << { id: "#{kind}:#{profile.id}", kind: kind, name: profile.user.name, city: profile.region,
          address: "Área de atendimento: #{profile.region}", latitude: location['latitude'], longitude: location['longitude'],
          approximate: true, note: 'Área de atendimento. Não representa posição em tempo real.' }
      end
    end
    if @query.present?
      points.select! { |item| I18n.transliterate([item[:name], item[:address], item[:city], item[:category]].compact.join(' ')).downcase.include?(@query) }
    end
    points.select! { |item| @kinds.include?(item[:kind]) } if @kinds.any?
    located, missing = points.partition { |item| item[:latitude] && item[:longitude] }
    { points: located, total: located.length, unlocated_count: missing.length,
      unlocated: missing.first(30).map { |item| item.slice(:id, :kind, :name, :address) },
      counts: located.group_by { |item| item[:kind] }.transform_values(&:length) }
  end

  private

  def point(record, kind, category: nil, address: nil)
    location = kind == 'destination' && (record.latitude.nil? || record.longitude.nil?) ? region(record.city.to_s) : {}
    { id: "#{kind}:#{record.id}", kind: kind, name: record.name, category: category || record.try(:category),
      address: address || record.try(:address), city: record.try(:city), latitude: record.latitude&.to_f || location['latitude'],
      longitude: record.longitude&.to_f || location['longitude'], approximate: record.geocoding_approximate || location.present?,
      phone: record.try(:phone), note: (location.present? ? 'Localização aproximada na cidade; endereço exato ainda não localizado.' : nil) }
  end

  def region(city)
    return {} if city.blank?
    @regions[city] ||= begin
      query = "#{city}, Bahia, Brasil"
      fingerprint = Digest::SHA256.hexdigest([query, city, true].join('|'))
      item = GeocodedAddress.find_by(fingerprint: fingerprint)
      if !item || (item.status == 'pending' && item.updated_at < 2.minutes.ago) || (%w[failed not_found].include?(item.status) && item.updated_at < 1.day.ago)
        item ||= GeocodedAddress.create_or_find_by!(fingerprint: fingerprint) { |entry| entry.query = query }
        item.update!(status: 'pending', updated_at: Time.current)
        GeocodeRegionJob.perform_later(city)
      end
      item.status == 'resolved' ? item.result : {}
    end
  end
end
