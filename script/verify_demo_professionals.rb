require Rails.root.join('lib/demo_seed_database')
abort 'Execute somente no banco de desenvolvimento.' unless DemoSeedDatabase.allowed?

# Regulariza somente os profissionais fictícios publicados pelo seed do MVP.
# Não altera turistas, cadastros reais nem as exigências da listagem pública.
guide_emails = (1..10).map { |number| format('guia%02d@cacautrip.test', number) }
driver_emails = (1..10).map { |number| format('motorista%02d@cacautrip.test', number) }
guide_ids = GuideProfile.where(moderation_status: 'published', verified_documents: true).select(:user_id)
driver_ids = DriverProfile.where(moderation_status: 'published', verified_cnh: true).select(:user_id)
guides = User.where(email: guide_emails, id: guide_ids, suspended: false)
drivers = User.where(email: driver_emails, id: driver_ids, suspended: false)
scope = guides.or(drivers)
count = scope.where(gov_verified: false).update_all(gov_verified: true, updated_at: Time.current)
puts "#{count} contas profissionais de demonstração verificadas. Turistas e demais contas preservados."
