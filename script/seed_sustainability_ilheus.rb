# Executar somente em development: bin/rails runner script/seed_sustainability_ilheus.rb
# Dados de apresentação: nomes fictícios, endereços de referência em Ilhéus.
# Não presume parceria ou aceitação de cupons por estabelecimentos reais.
abort 'Execute somente no banco de desenvolvimento.' unless Rails.env.development? && ActiveRecord::Base.connection.current_database == 'cacautrip_development'

notes_path = ENV.fetch('NOTES_PATH', Rails.root.join('..', 'notes.md').expand_path.to_s)
notes_parent = File.dirname(notes_path)
abort 'O diretório do notes.md precisa existir.' unless File.directory?(notes_parent)
admin = AdminUser.find_by(role: 'admin', active: true)
abort 'Cadastre primeiro uma conta administrativa ativa no painel.' unless admin
people = %w[turista01@cacautrip.test turista02@cacautrip.test].map { |email| User.find_by!(email: email) }
operator_password = 'ColetaIlheus!2026'
now = Time.current
points, operators, partners, rewards, codes, credited, vouchers = [], [], [], [], [], [], []

ActiveRecord::Base.transaction do
  [
    ['MLH', 'Ponto Verde Malhado', 'Avenida Ubaitaba, 71 - Malhado, Ilhéus - BA'],
    ['CQT', 'Ponto Verde Conquista', 'Avenida Princesa Isabel, 310 - Conquista, Ilhéus - BA'],
    ['ITB', 'Ponto Verde Avenida Itabuna', 'Avenida Itabuna, 2340 - Centro, Ilhéus - BA']
  ].each_with_index do |(key, name, address), index|
    point = EcoCollectionPoint.find_or_create_by!(name: name, city: 'Ilhéus') do |record|
      record.assign_attributes(address: address, active: true, materials: 'Papel, papelão, plástico e latas de alumínio limpos e secos',
        opening_hours: 'Segunda a sexta, das 9h às 17h; sábado, das 9h às 12h',
        description: 'Separe os materiais por tipo e apresente a entrega à equipe para receber seu código de pontos verdes.')
    end
    points << point
    operator = AdminUser.find_or_initialize_by(email: format('operador.coleta%02d@cacautrip.test', index + 1))
    if operator.new_record?
      operator.assign_attributes(name: "Operador #{name}", role: 'operador_coleta', eco_collection_point: point,
        active: true, password: operator_password, password_confirmation: operator_password)
      operator.save!
    elsif !operator.collection_operator? || operator.eco_collection_point_id != point.id
      abort "A conta #{operator.email} já existe com outra configuração. Nenhuma alteração foi aplicada."
    end
    operators << operator
    [50, 100, 150, 200, 300, 500].each_with_index do |value, position|
      code = EcoCollectionCode.find_or_create_by!(code: format('ECO-ILHEUS-%s-%02d', key, position + 1)) do |record|
        record.assign_attributes(eco_collection_point: point, issuer: operator, points: value, expires_at: now + 90.days)
      end
      codes << code
    end
  end

  [
    ['Sabores do Centro', 'Avenida Dois de Julho, 77 - Centro, Ilhéus - BA', 'Sabores regionais para completar o passeio pelo centro histórico.'],
    ['Café da Praça', 'Praça Dom Eduardo, 190 - Centro, Ilhéus - BA', 'Uma pausa para café e sabores do cacau no centro de Ilhéus.']
  ].each do |name, address, description|
    partners << EcoPartner.find_or_create_by!(name: name, city: 'Ilhéus') do |record|
      record.assign_attributes(address: address, description: description, active: true)
    end
  end

  offers = [
    ['R$ 20 no Sabores do Centro', 'partner', 'fixed', 20, 150, 60, nil, partners[0], 'Use em uma refeição no estabelecimento. Apresente seu cupom antes de fechar a conta.'],
    ['15% no Sabores do Centro', 'partner', 'percent', 15, 200, 80, 35, partners[0], 'Desconto em uma compra, limitado a R$ 35. Apresente seu cupom antes do pagamento.'],
    ['R$ 10 no Café da Praça', 'partner', 'fixed', 10, 80, 25, nil, partners[1], 'Aproveite uma pausa para café e resgate o benefício em uma compra no estabelecimento.'],
    ['20% no Café da Praça', 'partner', 'percent', 20, 120, 35, 20, partners[1], 'Um benefício para seu café: 20% de desconto, limitado a R$ 20.'],
    ['R$ 25 para sua próxima trilha', 'trail', 'fixed', 25, 200, 80, nil, nil, 'Selecione este cupom ao pagar uma trilha de guia no Cacau Trip.'],
    ['15% no seu transporte', 'driver', 'percent', 15, 150, 60, 30, nil, 'Após o aceite do motorista, use no pagamento da reserva. Desconto máximo de R$ 30.']
  ]
  offers.each do |title, scope, type, value, cost, minimum, maximum, partner, description|
    rewards << EcoReward.find_or_create_by!(title: title) do |record|
      record.assign_attributes(scope: scope, discount_type: type, discount_value: value, points_cost: cost,
        minimum_amount: minimum, maximum_discount: maximum, eco_partner: partner, description: description,
        stock: 50, expires_at: now + 90.days, active: true)
    end
  end

  # Códigos separados dos 18 disponíveis acima: deixam saldos e cupons prontos
  # sem esconder a origem dos pontos ou alterar as senhas das contas do app.
  [[people[0], [500, 500]], [people[1], [500, 300]]].each_with_index do |(person, values), person_index|
    values.each_with_index do |value, position|
      code = EcoCollectionCode.find_or_create_by!(code: format('ECO-ILHEUS-INICIAL-T%02d-%s', person_index + 1, ('A'.ord + position).chr)) do |record|
        record.assign_attributes(eco_collection_point: points[person_index], issuer: operators[person_index], points: value, expires_at: now + 90.days)
      end
      EcoProgram.claim(person, code.code)
      credited << code.reload
    end
  end
  [[people[0], [2, 4, 5]], [people[1], [0, 5]]].each_with_index do |(person, indexes), person_index|
    indexes.each do |index|
      voucher = EcoProgram.redeem(person, rewards[index].id, "seed-ilheus-t#{person_index + 1}-benefit-#{index + 1}")
      vouchers << voucher.reload
    end
  end
  AdminAudit.create!(admin_user: admin, action: 'eco.demo_seed', metadata: {
    collection_point_ids: points.map(&:id), partner_ids: partners.map(&:id), reward_ids: rewards.map(&:id),
    operator_ids: operators.map(&:id), collection_code_ids: codes.map(&:id), voucher_ids: vouchers.map(&:id)
  })
end

money = ->(value) { format('R$ %.2f', value.to_f).tr('.', ',') }
date = ->(value) { value.in_time_zone('America/Bahia').strftime('%d/%m/%Y %H:%M') }
benefit = ->(record) { record.discount_type == 'percent' ? "#{record.discount_value.to_f}%" : money.call(record.discount_value) }
cell = ->(value) { value.to_s.gsub('|', '/').gsub(/[\r\n]+/, ' ') }
section = <<~MD

<!-- SUSTAINABILITY_ILHEUS_START -->
## Sustentabilidade — apresentação em Ilhéus

Cadastrado em #{date.call(now)}. Dados exclusivamente de desenvolvimento: os nomes dos pontos e dos parceiros, os horários, os materiais aceitos e as promoções são fictícios para apresentar o fluxo. Os endereços usam referências publicadas de Ilhéus; isso não significa que o endereço real tenha um ponto Cacau Trip, aceite estes códigos ou participe do programa. Não apresentar estes cupons como promoções de empresas reais.

App: aba Eco, ao lado de Roteiros. Painel: http://localhost:3000/gestao. Pontos de coleta: http://localhost:3000/gestao/pontos-de-coleta. Códigos: http://localhost:3000/gestao/codigos-de-coleta. Validação presencial: http://localhost:3000/gestao/validar-beneficio.

### Pontos de coleta

| ID | Ponto | Cidade | Endereço de referência | Materiais | Atendimento de apresentação |
|---|---|---|---|---|---|
MD
points.each { |point| section << "| #{point.id} | #{cell.call(point.name)} | #{point.city} | #{cell.call(point.address)} | #{cell.call(point.materials)} | #{cell.call(point.opening_hours)} |\n" }
section << "\nAs coordenadas foram deixadas vazias: nenhum marcador de mapa foi inventado. O endereço aparece normalmente na lista do aplicativo.\n\n### Operadores de coleta\n\nEstas são contas AdminUser do painel, separadas do login do aplicativo. Cada operador só emite códigos do seu ponto. Não gerencia benefícios, locais ou outros usuários.\n\n| E-mail | Senha local | Ponto vinculado | Conta ativa |\n|---|---|---|---|\n"
operators.each do |operator|
  password_note = operator.authenticate(operator_password) ? "`#{operator_password}`" : 'Senha anterior preservada; consulte o administrador'
  section << "| #{operator.email} | #{password_note} | #{cell.call(operator.eco_collection_point.name)} | #{operator.active? ? 'Sim' : 'Não'} |\n"
end
section << "\n### Códigos de coleta para inserir no app\n\nEm Eco → Pontos de coleta, informe um destes códigos. Cada código pode creditar pontos para somente uma conta. O saldo cresce sem alterar a carteira financeira.\n\n| Código | Ponto | Pontos | Validade | Situação na geração desta nota |\n|---|---|---|---|---|\n"
codes.each do |code|
  status = code.claimed_at ? "Usado por usuário ##{code.claimed_by_id}" : code.voided_at ? 'Cancelado' : code.expires_at.past? ? 'Expirado' : 'Disponível'
  section << "| `#{code.code}` | #{cell.call(code.eco_collection_point.name)} | #{code.points} | #{date.call(code.expires_at)} | #{status} |\n"
end
section << "\n### Onde usar os cupons de parceiros\n\nOs nomes abaixo são estabelecimentos fictícios do conjunto de apresentação. Os endereços servem como referência geográfica; não há acordo real com o estabelecimento que ocupa o endereço.\n\n| ID | Parceiro de apresentação | Cidade | Endereço de referência |\n|---|---|---|---|\n"
partners.each { |partner| section << "| #{partner.id} | #{cell.call(partner.name)} | #{partner.city} | #{cell.call(partner.address)} |\n" }
section << "\n### Benefícios disponíveis para trocar pontos\n\n| ID | Benefício | Onde usar | Pontos necessários | Desconto | Compra mínima | Teto do desconto | Estoque atual | Válido até |\n|---|---|---|---|---|---|---|---|---|\n"
rewards.each do |reward|
  reward.reload
  where = reward.eco_partner&.name || (reward.scope == 'trail' ? 'Pagamento de trilha no app' : 'Pagamento de motorista no app')
  section << "| #{reward.id} | #{cell.call(reward.title)} | #{cell.call(where)} | #{reward.points_cost} | #{benefit.call(reward)} | #{money.call(reward.minimum_amount)} | #{reward.maximum_discount ? money.call(reward.maximum_discount) : 'Valor da compra'} | #{reward.stock || 'Ilimitado'} | #{date.call(reward.expires_at)} |\n"
end
section << "\n### Contas com pontos e cupons prontos\n\nAs senhas do aplicativo não foram alteradas; as contas originais usam `CacauMvp!2026`, salvo alteração manual posterior. Novos resgates no app gastam pontos normalmente.\n\n| Conta do app | Saldo após a preparação |\n|---|---|\n"
people.each { |person| section << "| #{person.email} | #{person.reload.eco_points} pontos |\n" }
section << "\n### Cupons já resgatados\n\nNão confundir os cupons VERDE com os códigos ECO de coleta: códigos ECO creditam pontos; cupons VERDE representam benefícios já trocados.\n\n| Conta | Cupom | Benefício | Uso | Compra mínima | Validade | Situação |\n|---|---|---|---|---|---|---|\n"
vouchers.each do |voucher|
  use = voucher.benefit.dig('partner', 'name') || (voucher.benefit['scope'] == 'trail' ? 'Checkout de trilha no app' : 'Checkout de motorista no app')
  status = voucher.expires_at.past? ? 'Expirado' : voucher.status
  section << "| #{voucher.user.email} | `#{voucher.code}` | #{cell.call(voucher.benefit['title'])} | #{cell.call(use)} | #{money.call(voucher.benefit['minimum_amount'])} | #{date.call(voucher.expires_at)} | #{status} |\n"
end
section << "\n### Créditos de preparação, já usados\n\nEstes códigos adicionais foram consumidos automaticamente para preparar as duas contas. Não fazem parte dos 18 códigos disponíveis para testar novas entregas. Os créditos e as trocas constam no extrato.\n\n| Código usado | Conta | Pontos creditados |\n|---|---|---|\n"
credited.each { |code| section << "| `#{code.code}` | #{code.claimed_by.email} | #{code.points} |\n" }
section << <<~MD

### Como apresentar o fluxo

1. Entre no app com uma das contas turista. Na aba Eco, confira os locais, os benefícios e os cupons.
2. Informe um código ECO disponível: os pontos entram no saldo e no extrato.
3. Em Benefícios, escolha uma oferta e confirme a troca por pontos. O cupom aparece em Meus cupons.
4. Para um parceiro, consulte e confirme o código VERDE no painel, em Validar benefício verde, usando admin ou suporte. O uso é único. O operador de coleta não tem acesso a essa validação.
5. Para trilha ou motorista, abra uma reserva elegível que aguarda pagamento. Escolha o cupom no checkout ou troque pontos por um novo benefício ali. Respeite o valor mínimo da compra. Pix aprova na quarta consulta e cartão mantém o fluxo existente.
6. Para gerar novos códigos, entre no painel com um operador acima. Ele escolhe os pontos que a entrega vale e emite um código apenas para o ponto vinculado.

### Fontes dos endereços de referência

- [Solutudo — reciclagem em Ilhéus](https://www.solutudo.com.br/empresas/ba/ilheus/reciclagem%2Bde%2Bmateriais): endereços publicados de Ecocicla (Avenida Ubaitaba, 71), Reciclagem Positivo (Avenida Princesa Isabel, 310) e Charles Reciclagem (Avenida Itabuna, 2340). Nenhuma parceria foi confirmada.
- [Bataclan — endereço publicado](https://bataclan.com.br/): Avenida Dois de Julho, 77, Centro. Referência de endereço para o parceiro fictício Sabores do Centro; não é um cupom do Bataclan.
- [Grupo Vesúvio — Centro](https://www.grupovesuvio.com.br/vesuvio-centro) e [referência do número do endereço](https://www.tripadvisor.com.br/Restaurant_Review-g303262-d6513155-Reviews-Bar_Vesuvio-Ilheus_State_of_Bahia.html): Praça Dom Eduardo, 190. Referência de endereço para o parceiro fictício Café da Praça; não é um cupom do Vesúvio.

Script: `cacautrip-api/script/seed_sustainability_ilheus.rb`. Pode ser repetido sem recriar códigos, duplicar créditos ou gastar pontos novamente nos mesmos resgates. Preserva estoques, senhas e usos já existentes. A situação e os saldos desta nota retratam a execução do script; o app e o painel mostram os valores atuais.
<!-- SUSTAINABILITY_ILHEUS_END -->
MD
notes = File.exist?(notes_path) ? File.read(notes_path) : "# Notas do projeto\n"
notes = notes.gsub(/\n?<!-- SUSTAINABILITY_ILHEUS_START -->.*?<!-- SUSTAINABILITY_ILHEUS_END -->\n?/m, '')
File.write(notes_path, notes + section)
puts "Ilhéus: #{points.size} pontos, #{partners.size} parceiros de apresentação, #{rewards.size} benefícios, #{codes.size} códigos de coleta, #{operators.size} operadores e #{vouchers.size} cupons preparados."
puts "Contas preparadas: #{people.map { |person| "#{person.email}=#{person.reload.eco_points} pontos" }.join(', ')}"
puts "Documentação e códigos gravados em #{notes_path}. Nenhuma senha anterior foi alterada."
