# Executar com: bundle exec rails runner script/seed_mvp.rb
# Somente contas fictícias deste conjunto são criadas/atualizadas; dados existentes são preservados.
password = 'CacauMvp!2026'
groups = {
  tourist: ['Ana Lima', 'Bruno Alves', 'Camila Rocha', 'Daniel Costa', 'Elisa Santos', 'Felipe Moura', 'Gabriela Reis', 'Henrique Dias', 'Isabela Melo', 'João Nunes'],
  driver: ['André Souza', 'Beatriz Lopes', 'Caio Ribeiro', 'Débora Freitas', 'Eduardo Ramos', 'Fernanda Luz', 'Gustavo Martins', 'Helena Barros', 'Igor Teixeira', 'Juliana Azevedo'],
  guide: ['Lucas Carvalho', 'Marina Oliveira', 'Nicolas Pinto', 'Olívia Castro', 'Pedro Vieira', 'Rafaela Brito', 'Samuel Ferreira', 'Talita Gomes', 'Vitor Correia', 'Yasmin Araújo']
}
accounts = {}
rows = []
comments = ['Experiência excelente! Pontualidade e atenção do começo ao fim.', 'Conhece muito bem a região e tornou nosso passeio especial.', 'Atendimento cuidadoso, comunicação fácil e tudo conforme combinado.']
cities = ['Ilhéus', 'Itacaré', 'Uruçuca', 'Serra Grande', 'Una']

User.transaction do
  groups.each do |role, names|
    accounts[role] = names.each_with_index.map do |name, index|
      email = "#{role == :tourist ? 'turista' : role == :driver ? 'motorista' : 'guia'}#{format('%02d', index + 1)}@cacautrip.test"
      user = User.find_or_initialize_by(email: email)
      user.assign_attributes(name: name, password: password, password_confirmation: password, gov_verified: role != :tourist,
        active_role: role.to_s, suspended: false, preferences: { region: cities[index % cities.length], interests: 'Praias, trilhas e gastronomia', notifications: true })
      user.save!
      if role == :driver
        profile = user.driver_profile || user.build_driver_profile
        profile.assign_attributes(vehicle_model: ['Renault Duster', 'Toyota Corolla', 'Chevrolet Spin', 'Hyundai HB20', 'Fiat Argo'][index % 5],
          license_plate: "CT#{format('%02d', index)}A#{format('%02d', index + 10)}", capacity: index % 5 == 2 ? 6 : 4,
          region: cities[index % cities.length], description: 'Transporte confortável para praias, aeroportos e passeios pela Costa do Cacau.',
          services: 'Transfer, passeios e transporte entre cidades', price: 90 + index * 15, available: true, accessible: index.even?,
          document_reference: "CNH-CT-#{format('%04d', index + 1)}", verified_cnh: true, moderation_status: 'published', availability: [],
          image_url: "https://api.dicebear.com/9.x/avataaars/png?seed=motorista#{index + 1}")
        profile.save!
      elsif role == :guide
        profile = user.guide_profile || user.build_guide_profile
        profile.assign_attributes(region: cities[index % cities.length], description: 'Descubra a cultura, a natureza e os sabores da Costa do Cacau com acompanhamento local.',
          specialization: ['Praias e natureza', 'Trilhas e ecoturismo', 'História e cultura', 'Fazendas de cacau', 'Gastronomia regional'][index % 5],
          languages: index.even? ? 'Português, Inglês' : 'Português, Espanhol', services: 'Passeios guiados e experiências culturais',
          price: 150 + index * 20, available: true, accessible: index.even?, document_reference: "CADASTUR-CT-#{format('%04d', index + 1)}",
          verified_documents: true, moderation_status: 'published', availability: [],
          image_url: "https://api.dicebear.com/9.x/avataaars/png?seed=guia#{index + 1}")
        profile.save!
      end
      rows << [role, name, email]
      user
    end
  end

  [:driver, :guide].each do |role|
    next if ENV['TRAIL_SEED_MODE'] == '1' && role == :guide
    accounts[role].each_with_index do |provider, index|
      type = role == :driver ? 'Motorista' : 'Guia'
      profile = role == :driver ? provider.driver_profile : provider.guide_profile
      3.times do |visit|
        tourist = accounts[:tourist][(index + visit) % 10]
        date = (Date.new(2026, 10, 1) + index + visit).strftime('%Y-%m-%d') + ' 09:00'
        booking = Booking.find_or_initialize_by(user: tourist, service_type: type, service_id: profile.id, date: date)
        if booking.new_record?
          booking.assign_attributes(total_amount: profile.price, people: 2, meeting_point: "Centro de #{cities[index % 5]}",
            dropoff_point: 'Praia e atrações da região', status: 'approved_waiting_payment', payment_status: 'pending', payment_method: 'credit_card',
            offer_by_id: tourist.id, offer_history: [{ user_id: tourist.id, amount: profile.price.to_s, at: Time.current.iso8601 }])
          booking.save!
          booking.with_lock do
            booking.approve_payment!
            booking.update!(status: 'completed', completed_at: Time.zone.parse(date) + 4.hours)
            booking.wallet_entries.where(kind: 'earning').update_all(status: 'available')
          end
        end
        review = Review.find_or_initialize_by(booking: booking)
        review.assign_attributes(user: tourist, rating: visit == 1 ? 4 : 5, comment: comments[visit], hidden: false)
        review.save!
      end
      tourist = accounts[:tourist][index]
      chat = Conversation.find_or_create_by!(tourist_id: tourist.id, guide_id: role == :guide ? provider.id : nil, driver_id: role == :driver ? provider.id : nil, booking_id: nil)
      chat.messages.find_or_create_by!(sender: tourist, content: 'Olá! Gostaria de combinar um passeio pela região. Você tem disponibilidade?')
      chat.messages.find_or_create_by!(sender: provider, content: 'Olá! Tenho sim. Podemos combinar por aqui a data, o encontro e os detalhes do passeio.')
    end
  end
end

notes = <<~TEXT
  # Acessos do MVP — Cacautrip

  Estas são contas fictícias para apresentação local. As avaliações e os históricos foram gerados para demonstração, não são depoimentos de clientes reais.
  Não utilize essas credenciais em produção.

  **Senha de todas as contas:** `#{password}`

TEXT
{ tourist: 'Turistas', driver: 'Motoristas', guide: 'Guias' }.each do |role, title|
  notes << "## #{title}\n\n| Nome | E-mail | Senha |\n|---|---|---|\n"
  rows.select { |row| row[0] == role }.each { |_, name, email| notes << "| #{name} | #{email} | #{password} |\n" }
  notes << "\n"
end
notes << "\nForam criadas 30 contas, 60 reservas concluídas e 60 avaliações. Guias e motoristas possuem saldo disponível na carteira e conversas anteriores ao pagamento.\n"
notes << "\nGov.br, pagamentos, assinaturas e saques continuam implementados como simulações locais. A titularidade de uma chave Pix não é verificada em um provedor externo; a opção de CPF usa apenas a referência da conta Gov.br, sem CPF real armazenado.\n"
File.write(ENV.fetch('NOTES_PATH', Rails.root.join('notes.md').to_s), notes)
puts 'Contas do MVP criadas: 10 turistas, 10 motoristas, 10 guias; 60 avaliações. Acessos gravados em notes.md.'
