require Rails.root.join('lib/demo_seed_database')
# Uso restrito ao banco LOCAL de desenvolvimento. Este script não faz backup.
connection = ActiveRecord::Base.connection
expected = DemoSeedDatabase.expected_database
unless DemoSeedDatabase.allowed? && ENV['RESET_DATABASE'] == expected && connection.current_database == expected
  abort 'Limpeza recusada: ambiente, host ou confirmação do banco não autorizado.'
end
connection.transaction do
  connection.execute('DROP SCHEMA public CASCADE')
  connection.execute('CREATE SCHEMA public')
end
puts 'Schema do banco autorizado limpo. Execute db:migrate e o seed de trilhas.'
