ENV['TRAIL_SEED_MODE'] = '1'
load Rails.root.join('script/seed_mvp.rb')

password = 'CacauMvp!2026'
places = {
  'Ilhéus' => [ ['Praça Dom Eduardo', 'Praça Dom Eduardo, Centro, Ilhéus', -14.798, -39.033], ['Centro histórico', 'Centro histórico de Ilhéus, Bahia', -14.797, -39.034], ['Orla da Avenida Soares Lopes', 'Avenida Soares Lopes, Ilhéus', -14.790, -39.029] ],
  'Itacaré' => [ ['Praia da Concha', 'Praia da Concha, Itacaré', -14.277, -38.990], ['Praia do Resende', 'Praia do Resende, Itacaré', -14.286, -38.985], ['Praia da Tiririca', 'Praia da Tiririca, Itacaré', -14.289, -38.986] ],
  'Uruçuca' => [ ['Praça central', 'Centro, Uruçuca, Bahia', -14.593, -39.282], ['Caminho da cabruca', 'Área de visitação rural, Uruçuca — acesso indicado pelo guia', nil, nil], ['Ponto de degustação', 'Região rural de Uruçuca — encontro combinado com o guia', nil, nil] ],
  'Serra Grande' => [ ['Praça de Serra Grande', 'Centro, Serra Grande, Uruçuca', -14.461, -39.039], ['Mirante de Serra Grande', 'Mirante de Serra Grande, Bahia', -14.464, -39.036], ['Praia do Pé de Serra', 'Praia do Pé de Serra, Serra Grande', -14.472, -39.034] ],
  'Una' => [ ['Centro de Una', 'Centro, Una, Bahia', -15.294, -39.075], ['Parada de observação', 'Região de Una — acesso e local exatos orientados pelo guia', nil, nil], ['Encontro com a cultura local', 'Centro, Una, Bahia', -15.2945, -39.076] ]
}
places.each do |city, points|
  points.each do |name, address, latitude, longitude|
    Destination.find_or_create_by!(name: name, city: city) do |place|
      place.assign_attributes(category: 'atração', description: 'Ponto de interesse da região. Conheça as experiências dos guias locais para planejar sua visita.',
        latitude: latitude, longitude: longitude, price: 0, duration_minutes: 45, accessible: false,
        rules: 'Confirme condições de acesso com o guia e respeite a sinalização local.', opening_hours: 'Conforme o local de visitação')
    end
  end
end

guides = User.where("email LIKE 'guia%@cacautrip.test'").order(:email).to_a
tourists = User.where("email LIKE 'turista%@cacautrip.test'").order(:email).to_a
guides.each_with_index do |guide, index|
  profile = guide.guide_profile
  city = profile.region
  points = places.fetch(city)
  2.times do |variant|
    title = variant.zero? ? "Caminhos e paisagens de #{city}" : "Sabores e cultura de #{city}"
    trail = profile.trails.find_or_initialize_by(title: title)
    trail.assign_attributes(description: variant.zero? ? 'Um passeio em grupo para conhecer paisagens e histórias locais, com paradas para contemplação e conversa com o guia.' : 'Uma experiência cultural para descobrir o cotidiano da região, seus sabores e sua relação com o cacau.',
      region: city, image_url: variant.zero? ? 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=1000&fit=crop' : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1000&fit=crop',
      difficulty: variant.zero? ? (index.even? ? 'easy' : 'moderate') : 'easy', route_mode: variant.zero? ? 'ordered' : 'flexible',
      status: 'published', duration_minutes: variant.zero? ? 180 : 240, distance_km: variant.zero? ? 3.5 : 2,
      price: variant.zero? ? 75 + index * 5 : 280 + index * 10, price_mode: variant.zero? ? 'per_person' : 'group',
      minimum_age: variant.zero? ? 10 : 0, accessible: variant == 1 && index.even?,
      included: 'Acompanhamento do guia, apresentação dos pontos e orientações do percurso.',
      not_included: 'Transporte até o encontro, refeições e despesas pessoais.',
      what_to_bring: 'Água, calçado confortável, proteção para sol e chuva e um lanche leve.',
      safety_notes: 'Informe ao guia necessidades de acessibilidade e limitações físicas antes da saída. Respeite as orientações durante o percurso.',
      cancellation_policy: 'Cancelamento pelo turista antes da saída. Em caso de condições inadequadas, o guia poderá cancelar a data e oferecer novas opções.')
    if trail.new_record?
      points.each_with_index do |(name, address, latitude, longitude), position|
        trail.stops.build(name: name, address: address, latitude: latitude, longitude: longitude,
          position: position, kind: position.zero? ? 'meeting' : position == points.length - 1 ? 'finish' : 'visit',
          duration_minutes: 30 + position * 10, description: ['Recepção do grupo e apresentação do passeio.', 'Parada para conhecer o local, ouvir histórias e tirar fotos.', 'Encerramento do passeio e orientações para o retorno.'][position], optional: false)
      end
    end
    trail.save!
    [2 + variant, 7 + variant, 14 + variant].each do |offset|
      time = Time.find_zone!('America/Bahia').local((Date.current + offset).year, (Date.current + offset).month, (Date.current + offset).day, 8 + variant, 0)
      trail.departures.find_or_create_by!(starts_at: time) do |departure|
        departure.assign_attributes(capacity: variant.zero? ? 12 : 8, meeting_point: points[0][1], notes: 'Chegue com antecedência para as orientações iniciais.', status: 'scheduled')
      end
    end
    3.times do |visit|
      day = Date.current - 30 + index * 2 + variant + visit * 3
      time = Time.find_zone!('America/Bahia').local(day.year, day.month, day.day, 8, 0)
      departure = trail.departures.find_or_create_by!(starts_at: time) { |row| row.assign_attributes(capacity: 12, meeting_point: points[0][1], status: 'finished') }
      tourist = tourists[(index + visit + variant) % tourists.length]
      booking = Booking.find_or_initialize_by(user: tourist, trail_departure: departure)
      if booking.new_record?
        total = departure.unit_price * (trail.price_mode == 'per_person' ? 2 : 1)
        snapshot = trail.attributes.except('created_at', 'updated_at').merge('stops' => trail.stops.as_json, 'guide_name' => guide.name, 'starts_at' => time.iso8601, 'meeting_point' => departure.meeting_point)
        booking.assign_attributes(service_type: 'Guia', service_id: profile.id, total_amount: total, people: 2,
          date: time.strftime('%Y-%m-%d %H:%M'), meeting_point: departure.meeting_point, dropoff_point: points.last[1],
          trail_snapshot: snapshot, status: 'approved_waiting_payment', payment_status: 'pending', payment_method: 'credit_card')
        booking.save!
        booking.with_lock do
          booking.approve_payment!
          booking.update!(status: 'completed', completed_at: time + trail.duration_minutes.minutes)
          booking.wallet_entries.update_all(status: 'available')
        end
      end
      Review.find_or_create_by!(booking: booking) do |review|
        review.assign_attributes(user: tourist, rating: visit == 1 ? 4 : 5, comment: ['Adoramos conhecer cada parada. O roteiro estava bem explicado e o guia foi muito atencioso.', 'Passeio organizado, com boas histórias e tempo para aproveitar os pontos.', 'Uma ótima forma de conhecer a região. Voltaria para fazer outra trilha!'][visit])
      end
    end
    # Reserva futura já paga para o guia ver a lista de participantes.
    next_departure = trail.departures.where(status: 'scheduled').order(:starts_at).first
    tourist = tourists[(index + variant) % tourists.length]
    unless next_departure.bookings.exists?(user: tourist)
      snapshot = trail.attributes.except('created_at', 'updated_at').merge('stops' => trail.stops.as_json, 'guide_name' => guide.name, 'starts_at' => next_departure.starts_at.iso8601, 'meeting_point' => next_departure.meeting_point)
      booking = next_departure.bookings.create!(user: tourist, service_type: 'Guia', service_id: profile.id, people: 2,
        total_amount: next_departure.unit_price * (trail.price_mode == 'per_person' ? 2 : 1),
        date: next_departure.starts_at.in_time_zone('America/Bahia').strftime('%Y-%m-%d %H:%M'), meeting_point: next_departure.meeting_point,
        trail_snapshot: snapshot, status: 'approved_waiting_payment', payment_status: 'pending', payment_method: 'credit_card')
      booking.with_lock { booking.approve_payment! }
    end
  end
  chat = Conversation.find_or_create_by!(tourist: tourists[index], guide: guide, driver: nil, booking_id: nil)
  chat.messages.find_or_create_by!(sender: tourists[index], content: 'Olá! Gostaria de saber mais sobre suas trilhas e os pontos de passagem.')
  chat.messages.find_or_create_by!(sender: guide, content: 'Olá! Cada trilha tem um percurso e um calendário próprios. Veja o roteiro completo e escolha a saída que combina com você.')
end
admin = User.find_or_initialize_by(email: 'admin@cacautrip.test')
admin.assign_attributes(name: 'Administração Cacautrip', password: password, admin: true, gov_verified: true, active_role: 'tourist')
admin.save!

notes_path = ENV.fetch('NOTES_PATH', Rails.root.join('notes.md').to_s)
notes = File.read(notes_path)
notes = notes.sub(/Foram criadas 30 contas,.*\n/, "Base renovada: 30 contas de usuários, #{Trail.count} trilhas criadas pelos guias, #{TrailDeparture.count} saídas e #{Review.count} avaliações.\n")
notes << "\n## Administração\n\nE-mail: admin@cacautrip.test\nSenha: #{password}\n"
notes << "\n## Trilhas e saídas\n\nCada guia possui duas trilhas com pontos e condições próprios. Uma usa ordem fixa e preço por pessoa; a outra tem ordem flexível e preço fechado por grupo. Há datas futuras, vagas ocupadas, reservas concluídas e avaliações específicas de cada trilha.\n"
notes << "\nOs percursos desta base são ilustrativos: endereços e coordenadas servem à apresentação do MVP e não representam rotas oficiais de navegação ou acessos autorizados.\n"
File.write(notes_path, notes)
puts "Nova base: #{User.count} contas (incluindo administrador), #{Trail.count} trilhas, #{TrailDeparture.count} saídas, #{Booking.count} reservas, #{Review.count} avaliações. Acessos atualizados em notes.md."
