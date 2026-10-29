# Ativa planos pagos simulados apenas nas seis contas locais de apresentação.
abort 'Execute somente no banco de desenvolvimento.' unless Rails.env.development? && ActiveRecord::Base.connection.current_database == 'cacautrip_development'
assignments = [
  ['guia01@cacautrip.test', 'guide', 'premium'],
  ['guia02@cacautrip.test', 'guide', 'featured'],
  ['guia03@cacautrip.test', 'guide', 'premium'],
  ['motorista01@cacautrip.test', 'driver', 'premium'],
  ['motorista02@cacautrip.test', 'driver', 'featured'],
  ['motorista03@cacautrip.test', 'driver', 'premium']
]
rows = []
ActiveRecord::Base.transaction do
  assignments.each do |email, type, plan|
    user = User.find_by!(email: email)
    profile = user.public_send("#{type}_profile")
    raise "A conta #{email} precisa de perfil publicado, disponível e Gov.br verificado para aparecer na busca." unless profile && profile.moderation_status == 'published' && profile.available? && user.gov_verified? && !user.suspended?
    user.with_lock do
      subscription = user.subscriptions.find_by(professional_type: type)
      unless subscription && subscription.status == 'active' && subscription.plan == plan && subscription.renews_at&.future?
        order = SubscriptionOrder.create!(user: user, professional_type: type, plan: plan,
          amount: Subscription::PLANS.fetch(plan), payment_method: 'credit_card', auto_renew: false)
        order.approve!
        subscription = user.subscriptions.find_by!(professional_type: type)
      end
      rows << [user.name, email, type, subscription.plan, subscription.renews_at, subscription.auto_renew]
    end
  end
end
path = ENV.fetch('NOTES_PATH', Rails.root.join('..', 'notes.md').expand_path.to_s)
section = "\n<!-- SPONSORED_DEMO_PLANS_START -->\n## Profissionais patrocinados — planos de apresentação\n\nPlanos pagos simulados, com pedido aprovado pelo fluxo normal de assinatura. A listagem prioriza Premium antes de Destaque, identifica ambos como Patrocinado e ordena por avaliação/preço dentro do mesmo plano. Outras contas e seus planos foram preservados. Sem alteração de senhas ou do saldo disponível: o registro da assinatura é um lançamento próprio com status paid.\n\n| Profissional | Conta | Perfil | Plano | Válido até (Bahia) | Renovação automática |\n|---|---|---|---|---|---|\n"
rows.each do |name, email, type, plan, renews, auto|
  section << "| #{name} | #{email} | #{type == 'guide' ? 'Guia' : 'Motorista'} | #{plan == 'premium' ? 'Premium' : 'Destaque'} | #{renews.in_time_zone('America/Bahia').strftime('%d/%m/%Y %H:%M')} | #{auto ? 'Sim' : 'Não'} |\n"
end
section << "\nAs senhas existentes foram preservadas (nas contas originais, CacauMvp!2026, salvo alteração manual posterior). A situação acima corresponde à execução do script. Depois do vencimento, sem renovação, o perfil volta a basic na listagem.\n\nScript: `cacautrip-api/script/seed_sponsored_professionals.rb`. Repetir durante a vigência do mesmo plano não gera nova cobrança/pedido.\n<!-- SPONSORED_DEMO_PLANS_END -->\n"
notes = File.exist?(path) ? File.read(path) : "# Notas do projeto\n"
notes = notes.gsub(/\n?<!-- SPONSORED_DEMO_PLANS_START -->.*?<!-- SPONSORED_DEMO_PLANS_END -->\n?/m, '')
File.write(path, notes + section)
puts "Planos ativos em #{rows.size} profissionais de demonstração."
rows.each { |name, email, type, plan, renews, _| puts "#{email}: #{plan} até #{renews.in_time_zone('America/Bahia').strftime('%d/%m/%Y')}" }
