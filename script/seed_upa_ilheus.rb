require Rails.root.join('lib/demo_seed_database')
abort 'Use somente o banco de desenvolvimento.' unless DemoSeedDatabase.allowed?
# SESAB: https://www.ba.gov.br/saude/upa-post/upa-ilheus
# CNES 2939363: https://cnes2.datasus.gov.br/Mod_Conjunto.asp?VCo_Unidade=2913602939363
# As duas referências identificam a mesma unidade, não duas UPAs diferentes.
place = EmergencyPoint.all.detect do |item|
  name = I18n.transliterate(item.name.to_s).downcase
  name.include?('upa') && (name.include?('esperanca') || name.strip == 'upa ilheus')
end || EmergencyPoint.new
place.assign_attributes(name: 'UPA da Esperança', category: 'upa', address: 'Avenida Esperança, s/n - Esperança, Ilhéus - BA')
place.save!
GeocodePlaceJob.perform_now('EmergencyPoint', place.id) if ENV.fetch('SEED_GEOCODE', '1') == '1' && (place.latitude.nil? || place.longitude.nil?)
puts "#{place.name}: #{place.reload.latitude && place.longitude ? 'localizada no mapa' : 'endereço cadastrado; coordenadas pendentes'}"
# CNES 9005919: pronto atendimento geral, não classificado como outra UPA.
pa = EmergencyPoint.find_or_initialize_by(name: 'Pronto Atendimento da Zona Sul')
pa.assign_attributes(category: 'pronto_atendimento', address: 'Rodovia Pontal-Buerarema, 294 - Nossa Senhora da Vitória, Ilhéus - BA, CEP 45655-510', phone: '(73) 3234-3736')
pa.save!
GeocodePlaceJob.perform_now('EmergencyPoint', pa.id) if ENV.fetch('SEED_GEOCODE', '1') == '1' && (pa.latitude.nil? || pa.longitude.nil?)
puts "#{pa.name}: #{pa.reload.latitude && pa.longitude ? 'localizado no mapa' : 'endereço cadastrado; coordenadas pendentes'}"
