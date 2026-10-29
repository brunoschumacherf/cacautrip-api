module Backoffice
  module NavigationHelper
    # Ícones vetoriais locais: sem fontes de ícones ou dependências externas.
    def management_icon(name, size: 20)
      paths = {
        'O' => ['M8 6V4h8v2', 'M4 6h16v14H4z', 'M4 11h16', 'M10 11v3h4v-3'],
        'A' => ['M5 5h14v11H9l-4 4V5z', 'M9 9h6', 'M9 12h4'],
        'T' => ['M3 5l6-2 6 2 6-2v16l-6 2-6-2-6 2V5z', 'M9 3v16', 'M15 5v16'],
        'S' => ['M20 4C10 3 3 8 5 15c2 7 14 5 15-11z', 'M4 21L15 10', 'M8 17v-5', 'M11 14h5'],
        'F' => ['M4 6h14v3', 'M4 6v14h17V9H5a2 2 0 010-4h13', 'M16 13h5v4h-5z'],
        'G' => ['M12 3l2 3 4-1 1 4 3 3-3 3-1 4-4-1-2 3-2-3-4 1-1-4-3-3 3-3 1-4 4 1 2-3z', 'M15 12a3 3 0 11-6 0 3 3 0 016 0'],
        'C' => ['M4 7h16v14H4z', 'M8 7V3h8v4', 'M9 13l2 2 4-4'],
        'overview' => ['M3 3h7v7H3z', 'M14 3h7v7h-7z', 'M3 14h7v7H3z', 'M14 14h7v7h-7z'],
        'chevron' => ['M9 6l6 6-6 6'],
        'logout' => ['M10 4H4v16h6', 'M9 12h12', 'M17 8l4 4-4 4'],
        'menu' => ['M4 6h16', 'M4 12h16', 'M4 18h16']
      }
      tag.svg(viewBox: '0 0 24 24', width: size, height: size, fill: 'none', stroke: 'currentColor',
        'stroke-width': 1.65, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': true, focusable: false) do
        safe_join(paths.fetch(name.to_s, paths['overview']).map { |path| tag.path(d: path) })
      end
    end

    def management_home_path
      current_admin_user.collection_operator? ? backoffice_eco_codes_path : backoffice_root_path
    end

    def management_sections
      if current_admin_user.collection_operator?
        return [{ title: 'Meu ponto de coleta', marker: 'C', open: true, items: [
          management_link('Emitir e consultar códigos', backoffice_eco_codes_path, controller_name == 'eco_codes')
        ] }]
      end

      sections = [
        { title: 'Operação', marker: 'O', items: [
          management_resource('bookings', 'Reservas e pagamentos'),
          management_resource('users', 'Contas do aplicativo'),
          management_resource('guides', 'Guias e aprovações'),
          management_resource('drivers', 'Motoristas e aprovações')
        ] },
        { title: 'Atendimento e moderação', marker: 'A', items: [
          management_link('Atendimento humano', backoffice_support_chats_path, controller_name == 'support_chats'),
          management_resource('reports', 'Denúncias'),
          management_resource('reviews', 'Avaliações'),
          management_resource('messages', 'Moderação de mensagens')
        ] },
        { title: 'Turismo e informações', marker: 'T', items: [
          management_resource('destinations', 'Atrações e serviços'),
          management_resource('trails', 'Trilhas dos guias'),
          management_resource('alerts', 'Comunicados e alertas'),
          management_resource('emergency_points', 'Emergência e apoio')
        ] },
        { title: 'Sustentabilidade', marker: 'S', items: [
          (management_link('Pontos de coleta', backoffice_collection_points_path, @resource == 'eco_collection_points') if can_read?('eco_collection_points')),
          management_resource('eco_partners', 'Estabelecimentos parceiros'),
          management_resource('eco_rewards', 'Benefícios e descontos'),
          management_link('Emitir códigos de coleta', backoffice_eco_codes_path, controller_name == 'eco_codes'),
          management_link('Validar cupom de parceiro', backoffice_eco_vouchers_path, controller_name == 'eco_vouchers')
        ] },
        { title: 'Financeiro', marker: 'F', items: [
          management_resource('wallet_entries', 'Carteiras e repasses'),
          management_resource('subscriptions', 'Assinaturas'),
          management_resource('subscription_orders', 'Pagamentos dos planos'),
          (management_link('Taxa de comissão', backoffice_commission_path, controller_name == 'finance') if current_admin_user.admin?)
        ] },
        { title: 'Equipe e sistema', marker: 'G', items: [
          management_resource('admin_users', 'Equipe e permissões'),
          (management_link('Relatórios e indicadores', backoffice_reports_path, controller_name == 'reports') if current_admin_user.admin?),
          management_resource('incidents', 'Falhas técnicas'),
          management_resource('audits', 'Auditoria')
        ] }
      ]
      sections.filter_map do |section|
        section[:items] = section[:items].compact
        next if section[:items].empty?
        section[:open] = section[:items].any? { |item| item[:active] } || (controller_name == 'dashboard' && section[:title] == 'Operação')
        section
      end
    end

    private

    def management_resource(resource, label)
      return unless can_read?(resource)
      management_link(label, backoffice_records_path(resource: resource), @resource == resource)
    end

    def management_link(label, path, active)
      { label: label, path: path, active: active }
    end
  end
end
