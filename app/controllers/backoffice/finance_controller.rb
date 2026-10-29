module Backoffice
  class FinanceController < BaseController
    before_action :require_administrator!

    def update_commission
      rate = BigDecimal(params[:percent].to_s.tr(',', '.')) / 100 rescue nil
      unless rate && rate.between?(0, 1)
        return redirect_to backoffice_commission_path, alert: 'Informe um percentual entre 0 e 100.', status: :see_other
      end
      PlatformSetting.transaction do
        setting = PlatformSetting.find_or_initialize_by(key: 'commission')
        setting.update!(value: { rate: rate.to_f })
        audit!('finance.commission', setting, percent: (rate * 100).to_f)
      end
      redirect_to backoffice_commission_path, notice: 'Taxa atualizada para os próximos pagamentos.', status: :see_other
    end

    def commission
      @rate = PlatformSetting.commission * 100
    end

    def refund
      booking = Booking.find(params[:id])
      reason = params[:reason].to_s.strip
      if reason.length < 10
        return redirect_to backoffice_record_path(resource: 'bookings', id: booking.id), alert: 'Informe um motivo com pelo menos dez caracteres.', status: :see_other
      end
      operation = lambda do
        booking.with_lock do
          if ['completed', 'cancelled', 'rejected'].include?(booking.status)
            booking.errors.add(:base, 'A reserva não permite cancelamento automático. Abra um chamado para revisão de serviços concluídos.')
            raise ActiveRecord::RecordInvalid, booking
          end
          booking.wallet_entries.where(kind: 'earning').update_all(status: 'cancelled')
          booking.update!(status: 'cancelled', payment_status: booking.payment_status == 'approved' ? 'refunded' : 'cancelled')
          audit!('finance.booking_cancel', booking, reason: reason.truncate(500))
        end
      end
      booking.trail_departure ? booking.trail_departure.with_lock { operation.call } : operation.call
      redirect_to backoffice_record_path(resource: 'bookings', id: booking.id), notice: 'Cancelamento registrado e saldo ajustado.', status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      redirect_to backoffice_record_path(resource: 'bookings', id: booking.id), alert: error.record.errors.full_messages.to_sentence, status: :see_other
    end
  end
end
