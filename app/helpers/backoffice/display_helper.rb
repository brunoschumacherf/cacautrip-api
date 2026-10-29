module Backoffice
  module DisplayHelper
    LABELS = {
      'eco_collection_point_id'=>'Ponto de coleta vinculado', 'eco_partner_id'=>'Estabelecimento parceiro', 'materials'=>'Materiais aceitos', 'points_cost'=>'Pontos para resgatar', 'stock'=>'Quantidade disponível (vazio = ilimitado)', 'scope'=>'Onde usar', 'discount_type'=>'Formato do desconto', 'discount_value'=>'Desconto (R$ ou %)', 'minimum_amount'=>'Valor mínimo da compra (R$)', 'maximum_discount'=>'Limite do desconto (R$, opcional)',
      'name'=>'Nome', 'email'=>'E-mail', 'role'=>'Papel', 'active'=>'Ativo', 'suspended'=>'Suspenso', 'created_at'=>'Criado em', 'updated_at'=>'Atualizado em',
      'user_id'=>'Usuário', 'admin_user_id'=>'Operador', 'region'=>'Região', 'moderation_status'=>'Situação do perfil', 'verified_documents'=>'Documentos aprovados',
      'verified_cnh'=>'CNH aprovada', 'available'=>'Disponível', 'vehicle_model'=>'Veículo', 'license_plate'=>'Placa', 'capacity'=>'Passageiros', 'document_reference'=>'Referência documental',
      'category'=>'Categoria', 'city'=>'Cidade', 'price'=>'Preço', 'status'=>'Situação', 'payment_status'=>'Pagamento', 'total_amount'=>'Total', 'fee_amount'=>'Comissão', 'professional_amount'=>'Líquido',
      'description'=>'Descrição', 'image_url'=>'Imagem (URL)', 'latitude'=>'Latitude', 'longitude'=>'Longitude', 'duration_minutes'=>'Duração em minutos', 'opening_hours'=>'Horários',
      'rules'=>'Regras', 'accessible'=>'Acessível', 'guide_required'=>'Exige guia', 'best_time'=>'Melhor período', 'provider_id'=>'Prestador', 'title'=>'Título', 'guide_profile_id'=>'Perfil do guia',
      'phone'=>'Telefone', 'address'=>'Endereço', 'kind'=>'Tipo', 'body'=>'Comunicado', 'source_url'=>'Fonte (URL)', 'expires_at'=>'Validade', 'rating'=>'Nota', 'comment'=>'Comentário',
      'hidden'=>'Oculto', 'booking_id'=>'Reserva', 'subject_type'=>'Tipo denunciado', 'subject_id'=>'Registro denunciado', 'reason'=>'Motivo', 'conversation_id'=>'Conversa', 'sender_id'=>'Remetente',
      'content'=>'Conteúdo', 'message'=>'Solicitação', 'reply'=>'Resposta', 'professional_type'=>'Perfil', 'plan'=>'Plano', 'auto_renew'=>'Renovação automática', 'renews_at'=>'Vencimento',
      'amount'=>'Valor', 'payment_method'=>'Método', 'paid_at'=>'Pago em', 'reference'=>'Referência', 'metadata'=>'Informações do registro', 'error_class'=>'Falha', 'location'=>'Origem',
      'request_id'=>'Identificador da requisição', 'trace'=>'Localização técnica', 'resolution'=>'Tratativa', 'last_sign_in_at'=>'Último acesso', 'action'=>'Ação', 'record_type'=>'Tipo', 'record_id'=>'Registro',
      'password'=>'Senha', 'password_confirmation'=>'Confirme a senha', 'specialization'=>'Especialidades', 'languages'=>'Idiomas', 'services'=>'Serviços', 'date'=>'Data do serviço', 'people'=>'Pessoas',
      'meeting_point'=>'Encontro', 'dropoff_point'=>'Desembarque', 'conditions'=>'Condições', 'service_type'=>'Serviço', 'service_id'=>'ID do serviço', 'completed_at'=>'Concluído em', 'active_role'=>'Perfil ativo', 'gov_verified'=>'Gov.br autenticado'
    }.freeze
    VALUES = { 'admin'=>'Administrador', 'suporte'=>'Suporte', 'pending'=>'Pendente', 'published'=>'Publicado', 'rejected'=>'Recusado', 'hidden'=>'Oculto',
      'operador_coleta'=>'Operador de coleta', 'partner'=>'Estabelecimento parceiro', 'trail'=>'Trilhas no app', 'fixed'=>'Valor em reais', 'percent'=>'Percentual',
      'open'=>'Aberto', 'answered'=>'Respondido', 'closed'=>'Encerrado', 'resolved'=>'Resolvido', 'dismissed'=>'Arquivado', 'investigating'=>'Em investigação',
      'active'=>'Ativo', 'cancelled'=>'Cancelado', 'draft'=>'Rascunho', 'archived'=>'Arquivado', 'approved'=>'Aprovado', 'refunded'=>'Estornado', 'confirmed'=>'Confirmado',
      'completed'=>'Concluído', 'pending_approval'=>'Aguardando aceite', 'approved_waiting_payment'=>'Aguardando pagamento', 'counteroffer'=>'Em negociação',
      'guide'=>'Guia', 'driver'=>'Motorista', 'tourist'=>'Turista', 'basic'=>'Básico', 'featured'=>'Destaque', 'premium'=>'Premium', 'credit_card'=>'Cartão', 'pix'=>'Pix',
      'earning'=>'Recebimento', 'payout'=>'Saque', 'subscription'=>'Assinatura' }.freeze

    def field_label(field)
      LABELS.fetch(field.to_s, field.to_s.humanize)
    end

    def display_value(record, field)
      value = record.public_send(field)
      return '—' if value.nil? || value == ''
      return value ? 'Sim' : 'Não' if value == true || value == false
      return l(value.in_time_zone('America/Bahia'), format: '%d/%m/%Y %H:%M') if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return number_to_currency(value, unit: 'R$ ', separator: ',', delimiter: '.') if %w[price total_amount fee_amount professional_amount amount].include?(field.to_s)
      return JSON.pretty_generate(value) if value.is_a?(Hash) || value.is_a?(Array)
      VALUES.fetch(value.to_s, value.to_s)
    end

    def field_options(resource, field)
      Registry::OPTIONS["#{resource}.#{field}"] || Registry::OPTIONS[field]
    end
  end
end
