module Backoffice
  class EcoVouchersController < BaseController
    before_action do
      head :forbidden unless current_admin_user.admin? || current_admin_user.suporte?
    end

    def index
      @voucher = EcoRedemption.includes(:user).find_by(code: params[:redemption_code].to_s.strip.upcase) if params[:redemption_code].present?
      flash.now[:alert] = 'Cupom não encontrado.' if params[:redemption_code].present? && !@voucher
    end

    def consume
      voucher = EcoRedemption.find_by!(code: params[:redemption_code].to_s.strip.upcase)
      EcoRedemption.transaction do
        EcoProgram.use_partner(voucher, current_admin_user)
        audit!('eco.partner_redeem', voucher)
      end
      redirect_to backoffice_eco_vouchers_path, notice: 'Benefício validado. O cupom não pode ser utilizado novamente.', status: :see_other
    rescue EcoProgram::Invalid => error
      redirect_to backoffice_eco_vouchers_path, alert: error.message, status: :see_other
    end
  end
end
