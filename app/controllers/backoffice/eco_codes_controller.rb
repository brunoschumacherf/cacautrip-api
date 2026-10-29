module Backoffice
  class EcoCodesController < BaseController
    def index
      @points = current_admin_user.collection_operator? ? EcoCollectionPoint.available.where(id: current_admin_user.eco_collection_point_id) : EcoCollectionPoint.available
      scope = EcoCollectionCode.includes(:eco_collection_point, :issuer)
      scope = scope.where(issuer: current_admin_user) unless current_admin_user.admin?
      @page = [params[:page].to_i, 1].max
      @codes = scope.order(id: :desc).offset((@page - 1) * 30).limit(31).to_a
      @more = @codes.size > 30
      @codes = @codes.first(30)
    end

    def create
      return redirect_to backoffice_eco_codes_path, alert: 'Aguarde antes de gerar outros códigos.', status: :see_other unless AuthenticationThrottle.allow?("eco-issue:#{current_admin_user.id}")
      point_id = current_admin_user.collection_operator? ? current_admin_user.eco_collection_point_id : params[:eco_collection_point_id]
      point = EcoCollectionPoint.available.find(point_id)
      expires = params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : 30.days.from_now
      EcoCollectionCode.transaction do
        code = EcoCollectionCode.create!(eco_collection_point: point, issuer: current_admin_user, points: params[:points], expires_at: expires)
        audit!('eco.code_issue', code, points: code.points, collection_point_id: point.id)
      end
      redirect_to backoffice_eco_codes_path, notice: 'Código gerado. Entregue-o ao cliente após receber os materiais.', status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      redirect_to backoffice_eco_codes_path, alert: (error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : 'Data inválida.'), status: :see_other
    end

    def void
      return head :forbidden unless current_admin_user.admin?
      code = EcoCollectionCode.find(params[:id])
      code.with_lock do
        return redirect_to backoffice_eco_codes_path, alert: 'Um código já resgatado não pode ser cancelado.', status: :see_other if code.claimed_at
        code.update!(voided_at: Time.current)
        audit!('eco.code_void', code)
      end
      redirect_to backoffice_eco_codes_path, notice: 'Código cancelado.', status: :see_other
    end
  end
end
