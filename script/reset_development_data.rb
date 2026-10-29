# Uso restrito ao banco LOCAL de desenvolvimento. Este script não faz backup.
connection = ActiveRecord::Base.connection
expected = 'cacautrip_development'
unless Rails.env.development? && ENV['RESET_DATABASE'] == expected && connection.current_database == expected
  abort 'Limpeza recusada: ambiente ou banco diferente de cacautrip_development.'
end
connection.transaction do
  connection.execute('DROP SCHEMA public CASCADE')
  connection.execute('CREATE SCHEMA public')
end
puts 'Schema do banco de desenvolvimento limpo. Execute db:migrate e o seed de trilhas.'
