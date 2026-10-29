module Backoffice
  class RecordsController < BaseController
    before_action :load_resource
    before_action :require_write!, only: [:new, :create, :edit, :update, :destroy]
    before_action :load_record, only: [:show, :edit, :update, :destroy]

    def index
      scope = filtered_scope
      @total = scope.count
      @page = params[:page].to_i.clamp(1, [(@total / 25.0).ceil, 1].max)
      @records = scope.order(created_at: :desc).offset((@page - 1) * 25).limit(25)
    end

    def show
      audit!('record.view', @record) unless @resource == 'audits'
      @details = detail_fields
    end

    def new
      return head :forbidden unless @spec[:create]
      @record = @klass.new
      if @resource == 'admin_users' && %w[admin suporte].include?(params[:role])
        @record.role = params[:role]
      end
      render :form
    end

    def edit
      render :form
    end

    def create
      return head :forbidden unless @spec[:create]
      @record = @klass.new(permitted_attributes)
      persist('record.create')
    end

    def update
      @record.assign_attributes(permitted_attributes)
      persist('record.update')
    end

    def destroy
      return head :forbidden unless @spec[:delete] && current_admin_user.admin?
      @record.class.transaction do
        @record.destroy!
        audit!('record.delete', @record)
      end
      redirect_to backoffice_records_path(resource: @resource), notice: 'Registro removido.', status: :see_other
    end

    private

    def load_resource
      @resource = params[:resource].to_s
      @spec = Registry::RESOURCES[@resource]
      return render plain: 'Área não encontrada.', status: :not_found unless @spec
      return render plain: 'Você não tem permissão para acessar esta área.', status: :forbidden unless can_read?(@resource)
      @klass = @spec.fetch(:model).constantize
    end

    def load_record
      @record = @klass.find(params[:id])
    end

    def require_write!
      render plain: 'Seu perfil permite apenas consulta nesta área.', status: :forbidden unless can_write?(@resource) && @spec[:edit].any?
    end

    def filtered_scope
      scope = @klass.all
      fields = @spec[:search]
      if params[:q].present? && fields.any?
        query = "%#{@klass.sanitize_sql_like(params[:q].to_s.truncate(150))}%"
        scope = scope.where(fields.map { |field| "#{@klass.connection.quote_column_name(field)} ILIKE :query" }.join(' OR '), query: query)
      end
      if params[:status].present? && @klass.column_names.include?('status')
        scope = scope.where(status: params[:status])
      end
      scope
    end

    def permitted_attributes
      attributes = params.require(:record).permit(*@spec[:edit])
      if @resource == 'admin_users' && @record&.persisted? && attributes[:password].blank?
        attributes.delete(:password)
        attributes.delete(:password_confirmation)
      end
      attributes
    end

    def persist(event)
      @record.class.transaction do
        AdminUser.where(role: 'admin', active: true).order(:id).lock.load if @resource == 'admin_users'
        if %w[guides drivers].include?(@resource) && @record.moderation_status == 'published'
          unless @record.user.gov_verified? && @record.document_reference.present?
            @record.errors.add(:base, 'Aprovação exige conta Gov.br autenticada e referência documental preenchida')
            raise ActiveRecord::RecordInvalid, @record
          end
          @record.public_send("#{@resource == 'guides' ? 'verified_documents' : 'verified_cnh'}=", true)
        end
        @record.auto_renew = false if @resource == 'subscriptions' && @record.status == 'cancelled'
        reply_changed = @resource == 'tickets' && @record.will_save_change_to_reply?
        fields = @record.changed - %w[password_digest document_reference]
        @record.save!
        audit!(event, @record, fields: fields)
        if @resource == 'tickets' && reply_changed && @record.reply.present?
          Notification.create!(user: @record.user, title: 'Resposta do suporte', body: @record.reply, kind: 'support', target: 'suporte')
        elsif %w[guides drivers].include?(@resource)
          Notification.create!(user: @record.user, title: 'Perfil profissional atualizado', body: @record.moderation_status, kind: 'profile', target: 'perfil')
        end
      end
      redirect_to backoffice_record_path(resource: @resource, id: @record.id), notice: 'Alterações salvas.', status: :see_other
    rescue ActiveRecord::RecordInvalid
      render :form, status: :unprocessable_entity
    end

    def detail_fields
      extra = case @resource
      when 'users' then %w[active_role gov_verified]
      when 'guides' then %w[specialization languages description services document_reference]
      when 'drivers' then %w[region services document_reference]
      when 'bookings' then %w[service_id date people meeting_point dropoff_point conditions payment_method professional_amount completed_at]
      when 'reviews' then %w[comment]
      when 'reports' then %w[reason]
      when 'messages' then %w[content]
      when 'tickets' then %w[message reply]
      when 'incidents' then %w[request_id trace resolution]
      when 'audits' then %w[request_id metadata]
      when 'wallet_entries' then %w[reference metadata]
      else @spec[:edit] - %w[password password_confirmation]
      end
      (@spec[:columns] + extra).uniq.select { |field| @record.respond_to?(field) }
    end
  end
end
