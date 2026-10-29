require Rails.root.join('lib/demo_seed_database')
abort 'Use somente o banco de desenvolvimento.' unless DemoSeedDatabase.allowed?
# Fontes oficiais e endereços consultados em 29/10/2026; não presume disponibilidade.
places = [
  ['Hospital Regional Costa do Cacau', 'hospital', 'Rodovia Jorge Amado (BR-415), km 4,5, s/n - Banco da Vitória, Ilhéus - BA', '(73) 3235-5300'],
  ['Hospital Materno Infantil Dr. Joaquim Sampaio', 'hospital', 'Avenida Brasil, s/n - Conquista, Ilhéus - BA', '(73) 3234-3850'],
  ['DEPAM - Polícia Civil de Ilhéus', 'delegacia', 'Avenida Coronel Misael Tavares, s/n - Ilhéus - BA, CEP 45653-650', nil],
  ['Delegacia da Polícia Federal em Ilhéus', 'delegacia', 'Avenida Governador Roberto Santos, 11 - Fundão, Ilhéus - BA, CEP 45658-635', nil]
]
places.each do |name, category, address, phone|
  place = EmergencyPoint.find_or_initialize_by(name: name)
  place.assign_attributes(category: category, address: address)
  place.phone = phone if phone
  place.save!
  GeocodePlaceJob.perform_now('EmergencyPoint', place.id) if ENV.fetch('SEED_GEOCODE', '1') == '1' && (place.latitude.nil? || place.longitude.nil?)
  puts "#{place.name}: #{place.reload.latitude && place.longitude ? 'localizado no mapa' : 'endereço cadastrado; localização pendente'}"
  STDOUT.flush
end
