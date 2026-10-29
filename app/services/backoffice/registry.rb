module Backoffice
  module Registry
    SUPPORT_READ = %w[users bookings tickets reports reviews messages incidents alerts emergency_points].freeze
    SUPPORT_WRITE = %w[tickets reports reviews messages incidents].freeze
    RESOURCES = {
      'users' => { model: 'User', label: 'Usuários', columns: %w[name email suspended created_at], edit: %w[name email suspended], search: %w[name email] },
      'guides' => { model: 'GuideProfile', label: 'Guias', columns: %w[user_id region moderation_status verified_documents available], edit: %w[moderation_status verified_documents available region specialization languages description services document_reference], search: %w[region specialization] },
      'drivers' => { model: 'DriverProfile', label: 'Motoristas', columns: %w[user_id vehicle_model license_plate capacity moderation_status verified_cnh], edit: %w[moderation_status verified_cnh available vehicle_model license_plate capacity region services document_reference], search: %w[vehicle_model license_plate region] },
      'destinations' => { model: 'Destination', label: 'Atrações e serviços', columns: %w[name category city price active], edit: %w[name category city description image_url latitude longitude price duration_minutes opening_hours rules accessible guide_required active best_time provider_id], search: %w[name city category], create: true },
      'trails' => { model: 'Trail', label: 'Trilhas dos guias', columns: %w[title guide_profile_id region status price], edit: %w[status], search: %w[title region] },
      'emergency_points' => { model: 'EmergencyPoint', label: 'Emergência', columns: %w[name category phone address], edit: %w[name category phone address latitude longitude], search: %w[name category address], create: true, delete: true },
      'alerts' => { model: 'Alert', label: 'Comunicados e alertas', columns: %w[title kind region expires_at], edit: %w[title body kind region source_url expires_at], search: %w[title region kind], create: true, delete: true },
      'reviews' => { model: 'Review', label: 'Avaliações', columns: %w[user_id booking_id rating hidden created_at], edit: %w[hidden], search: %w[comment] },
      'reports' => { model: 'Report', label: 'Denúncias', columns: %w[subject_type subject_id user_id status created_at], edit: %w[status], search: %w[reason subject_type] },
      'messages' => { model: 'Message', label: 'Conteúdos do chat', columns: %w[conversation_id sender_id hidden created_at], edit: %w[hidden], search: [] },
      'tickets' => { model: 'SupportTicket', label: 'Solicitações de suporte', columns: %w[user_id status created_at updated_at], edit: %w[reply status], search: %w[message] },
      'bookings' => { model: 'Booking', label: 'Reservas e pagamentos', columns: %w[user_id service_type status payment_status total_amount fee_amount created_at], edit: [], search: %w[status service_type] },
      'wallet_entries' => { model: 'WalletEntry', label: 'Carteiras e repasses', columns: %w[user_id booking_id kind amount status created_at], edit: [], search: %w[kind status] },
      'subscriptions' => { model: 'Subscription', label: 'Assinaturas', columns: %w[user_id professional_type plan status auto_renew renews_at], edit: %w[status auto_renew], search: %w[plan status] },
      'subscription_orders' => { model: 'SubscriptionOrder', label: 'Pagamentos de planos', columns: %w[user_id plan amount status payment_method paid_at], edit: [], search: %w[plan status] },
      'incidents' => { model: 'SystemIncident', label: 'Falhas técnicas', columns: %w[error_class location status created_at], edit: %w[status resolution], search: %w[error_class location] },
      'admin_users' => { model: 'AdminUser', label: 'Equipe e permissões', columns: %w[name email role active last_sign_in_at], edit: %w[name email role active password password_confirmation], search: %w[name email], create: true },
      'audits' => { model: 'AdminAudit', label: 'Auditoria', columns: %w[admin_user_id action record_type record_id created_at], edit: [], search: %w[action record_type] }
    }.freeze
    BOOLEAN_FIELDS = %w[suspended active available accessible guide_required verified_documents verified_cnh hidden auto_renew].freeze
    TEXT_FIELDS = %w[description services body rules message reason reply resolution safety_notes cancellation_policy what_to_bring included not_included trace].freeze
    NUMBER_FIELDS = %w[latitude longitude price capacity duration_minutes provider_id].freeze
    OPTIONS = {
      'moderation_status' => %w[pending published rejected hidden],
      'role' => %w[admin suporte],
      'reports.status' => %w[open resolved dismissed],
      'tickets.status' => %w[open answered closed],
      'subscriptions.status' => %w[active cancelled],
      'trails.status' => %w[draft published archived hidden],
      'incidents.status' => %w[open investigating resolved]
    }.freeze
  end
end
