require Rails.root.join('lib/demo_seed_database')
abort 'Use somente o banco de desenvolvimento.' unless DemoSeedDatabase.allowed?
[EcoCollectionPoint, EcoPartner, Destination, TrailStop, EmergencyPoint].each do |model|
  model.where(latitude: nil).or(model.where(longitude: nil)).find_each do |record|
    GeocodePlaceJob.perform_now(model.name, record.id)
    record.reload
    puts "#{model.name} ##{record.id}: #{record.latitude && record.longitude ? 'localizado' : 'endereço ainda não localizado'}"
    STDOUT.flush
  end
end
[GuideProfile, DriverProfile].each do |model|
  model.distinct.pluck(:region).compact.flat_map { |region| region.split(/[,;\/]/).first }.uniq.each do |city|
    GeocodeRegionJob.perform_now(city.strip) if city.present?
  end
end
