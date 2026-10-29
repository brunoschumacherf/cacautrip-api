abort 'Execute somente no banco de desenvolvimento.' unless Rails.env.development? && ActiveRecord::Base.connection.current_database == 'cacautrip_development'
count = User.update_all(gov_verified: false, updated_at: Time.current)
puts "Gov.br: #{count} usuários atualizados para gov_verified=false. Perfis e demais dados preservados."
path = ENV.fetch('NOTES_PATH', Rails.root.join('notes.md').to_s)
if File.exist?(path)
  notes = File.read(path).gsub(/\n?<!-- GOV_STATUS_START -->.*?<!-- GOV_STATUS_END -->\n?/m, '')
  notes << "\n<!-- GOV_STATUS_START -->\n## Verificação Gov.br\n\nTodas as contas do aplicativo foram atualizadas para gov_verified=false. A conta começa não verificada. Ao clicar em Verificar com Gov.br em Minha conta, o mock atualiza gov_verified para true e libera o cadastro e a troca de perfil profissional. A integração real com Gov.br é futura. Os dados profissionais antigos foram preservados, mas anúncios que exigem Gov.br não aparecem publicamente. AdminUser e os acessos do painel Rails permanecem independentes.\n<!-- GOV_STATUS_END -->\n"
  File.write(path, notes)
end

