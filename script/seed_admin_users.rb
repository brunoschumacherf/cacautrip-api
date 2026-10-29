# Provisiona somente as duas contas locais da equipe e registra os acessos.
require 'securerandom'
abort 'Use apenas development para provisionar contas de apresentação.' unless Rails.env.development?
accounts = [
  { name: 'Administração Cacau Trip', email: 'admin.painel@cacautrip.test', role: 'admin' },
  { name: 'Suporte Cacau Trip', email: 'suporte@cacautrip.test', role: 'suporte' }
]
created = []
AdminUser.transaction do
  accounts.each do |attributes|
    password = SecureRandom.urlsafe_base64(18) + '!Ct9'
    user = AdminUser.find_or_initialize_by(email: attributes[:email])
    user.assign_attributes(attributes.merge(password: password, password_confirmation: password, active: true))
    user.save!
    created << attributes.merge(password: password)
  end
end
path = ENV.fetch('NOTES_PATH', Rails.root.join('notes.md').to_s)
notes = File.exist?(path) ? File.read(path) : "# Acessos do projeto\n"
section = "\n<!-- BACKOFFICE_ACCESS_START -->\n## Painel Rails — equipe\n\nAcesso: http://localhost:3000/gestao (ou /admin). Login em http://localhost:3000/gestao/entrar.\n\nEstas contas pertencem ao model AdminUser, separado das contas do aplicativo. Credenciais locais de apresentação; não usar em produção.\n\n| Papel | Nome | E-mail | Senha |\n|---|---|---|---|\n"
created.each { |entry| section << "| #{entry[:role]} | #{entry[:name]} | #{entry[:email]} | `#{entry[:password]}` |\n" }
section << "\n- admin: administração integral, aprovações, conteúdo, finanças, relatórios, auditoria e equipe.\n- suporte: consulta de usuários/reservas e tratamento de chamados, denúncias, avaliações, mensagens e falhas. Sem alterações financeiras, aprovação de profissionais ou gestão da equipe.\n\nAs contas de administração do aplicativo listadas acima não dão acesso automático a este painel.\n<!-- BACKOFFICE_ACCESS_END -->\n"
notes = notes.gsub(/\n?<!-- BACKOFFICE_ACCESS_START -->.*?<!-- BACKOFFICE_ACCESS_END -->\n?/m, '')
File.write(path, notes + section)
puts 'AdminUser: contas admin e suporte criadas/atualizadas. Credenciais gravadas no notes.md da raiz.'
