require Rails.root.join('lib/demo_seed_database')
# Executado após db:prepare pelo rebuild_demo_data.sh.
abort 'Use somente development no banco cacautrip_development.' unless DemoSeedDatabase.allowed?
ENV['NOTES_PATH'] ||= Rails.root.join('..', 'notes.md').expand_path.to_s
ENV['SEED_GEOCODE'] ||= '1'
abort 'O diretório do notes.md não existe.' unless File.directory?(File.dirname(ENV['NOTES_PATH']))

# Evita notificações e jobs concorrentes durante a carga. A geocodificação
# é executada explicitamente depois que todos os registros existem.
class DemoDataSeedQueue
  def enqueue(_job); end
  def enqueue_at(_job, _timestamp); end
end

original_adapter = ActiveJob::Base.queue_adapter
ActiveJob::Base.queue_adapter = DemoDataSeedQueue.new
begin
  %w[
    db/seeds.rb
    script/seed_trails_mvp.rb
    script/verify_demo_professionals.rb
    script/seed_admin_users.rb
    script/seed_sponsored_professionals.rb
    script/seed_sustainability_ilheus.rb
    script/seed_support_places_ilheus.rb
    script/seed_upa_ilheus.rb
  ].each do |path|
    puts "\n[Dados] #{path}"
    load Rails.root.join(path)
  end
  load Rails.root.join('script/backfill_map_coordinates.rb') if ENV['SEED_GEOCODE'] == '1'

  counts = {
    'Contas do aplicativo' => User.count, 'Guias' => GuideProfile.count,
    'Motoristas' => DriverProfile.count, 'Trilhas' => Trail.count,
    'Saídas' => TrailDeparture.count, 'Reservas' => Booking.count,
    'Avaliações' => Review.count, 'Destinos' => Destination.count,
    'Pontos de apoio' => EmergencyPoint.count,
    'Pontos de coleta' => EcoCollectionPoint.count, 'Parceiros' => EcoPartner.count,
    'Contas do painel' => AdminUser.count
  }
  section = "\n<!-- DEMO_REBUILD_START -->\n## Recriação da base de apresentação\n\nGerada em #{Time.current.in_time_zone('America/Bahia').strftime('%d/%m/%Y %H:%M')}.\n\n"
  counts.each { |label, count| section << "- #{label}: #{count}\n" }
  section << "\nTuristas começam sem Gov.br verificado. Profissionais fictícios estão verificados e publicados; novas contas precisam usar Verificar com Gov.br em Minha conta. Os fluxos simulados de Gov.br e pagamentos foram preservados.\n"
  section << "\nGeocodificação: #{ENV['SEED_GEOCODE'] == '1' ? 'solicitada; depende da disponibilidade do provedor.' : 'não solicitada; endereços sem coordenadas precisam de localização posterior.'}\n"
  section << "\nComando na raiz: `bash cacautrip-api/script/rebuild_demo_data.sh --reset --build`. Apaga os dados locais após salvar backup.\n<!-- DEMO_REBUILD_END -->\n"
  path = ENV.fetch('NOTES_PATH')
  notes = File.read(path).gsub(/\n?<!-- DEMO_REBUILD_START -->.*?<!-- DEMO_REBUILD_END -->\n?/m, '')
  File.write(path, notes + section)
  puts "\nCarga concluída. Contas, senhas, códigos e cupons: #{path}"
ensure
  ActiveJob::Base.queue_adapter = original_adapter
end
