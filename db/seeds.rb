# Dados de demonstração. Edite informações operacionais pelo painel administrativo.
[
  ['Praia dos Milionários', 'praia', 'Ilhéus', -14.862, -39.025, 0, false],
  ['Centro histórico de Ilhéus', 'atração', 'Ilhéus', -14.797, -39.034, 0, true],
  ['Caminho do cacau', 'passeio', 'Ilhéus', -14.790, -39.080, 60, false],
  ['Trilha da Mata Atlântica', 'trilha', 'Itacaré', -14.320, -38.998, 40, false],
  ['Sabores da Costa do Cacau', 'restaurante', 'Ilhéus', -14.800, -39.030, 80, true],
  ['Hospedagem na Costa', 'pousada', 'Itacaré', -14.280, -38.996, 180, true]
].each do |name, category, city, latitude, longitude, price, accessible|
  Destination.find_or_create_by!(name: name) do |destination|
    destination.assign_attributes(category: category, city: city, latitude: latitude, longitude: longitude, price: price,
      accessible: accessible, description: 'Sugestão demonstrativa. Confirme preços, horários e condições com o prestador antes da visita.',
      opening_hours: 'Consulte o prestador', rules: 'Respeite a sinalização e preserve o ambiente.', best_time: 'Consulte as condições locais',
      guide_required: category == 'trilha')
  end
end

if ENV['ADMIN_EMAIL'].present? && ENV['ADMIN_PASSWORD'].present?
  admin = User.find_or_initialize_by(email: ENV['ADMIN_EMAIL'])
  admin.name = 'Administração' if admin.name.blank?
  admin.password = ENV['ADMIN_PASSWORD'] if admin.new_record?
  admin.admin = true
  admin.save!
end
