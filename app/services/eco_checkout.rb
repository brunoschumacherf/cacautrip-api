class EcoCheckout
  class Invalid < StandardError; end

  def self.scope_for(booking)
    return 'trail' if booking.service_type == 'Guia' && booking.trail_departure_id.present?
    'driver' if booking.service_type == 'Motorista'
  end

  def self.available_for(booking)
    kind = scope_for(booking)
    return EcoRedemption.none unless kind
    booking.user.eco_redemptions.where('expires_at > ?', Time.current)
      .where("benefit ->> 'scope' = ?", kind)
      .where("status = 'available' OR (status = 'reserved' AND booking_id = ?)", booking.id)
      .order(:expires_at, :id)
  end

  # O chamador mantém o lock da reserva. Cupons são travados em ordem estável.
  def self.apply!(booking, voucher_id)
    previous = booking.eco_redemption
    ids = [previous&.id, voucher_id.presence].compact
    locked = booking.user.eco_redemptions.where(id: ids).order(:id).lock.to_a
    voucher = voucher_id.present? ? locked.find { |item| item.id.to_s == voucher_id.to_s } : nil
    raise Invalid, 'Cupom não encontrado na sua conta.' if voucher_id.present? && !voucher
    if voucher
      validate!(booking, voucher)
      amount = voucher.discount_for(booking.total_amount)
      raise Invalid, 'O valor da reserva não atende às condições deste desconto.' unless amount.positive?
      if previous && previous.id != voucher.id
        locked.find { |item| item.id == previous.id }.update!(booking: nil, status: 'available', used_at: nil)
      end
      voucher.update!(booking: booking, status: 'reserved')
      booking.update!(discount_amount: amount, eco_discount: { redemption_id: voucher.id, title: voucher.benefit['title'] })
    else
      release!(booking, preserve: false)
    end
    booking.association(:eco_redemption).reset
  end

  def self.consume!(booking)
    voucher = booking.eco_redemption
    return unless voucher
    voucher.with_lock do
      validate!(booking, voucher)
      raise Invalid, 'O desconto da reserva mudou. Selecione novamente seu cupom.' unless voucher.discount_for(booking.total_amount) == booking.discount_amount
      voucher.update!(status: 'used', used_at: Time.current)
    end
  end

  def self.release!(booking, preserve: true)
    voucher = booking.eco_redemption
    voucher&.with_lock { voucher.update!(booking: nil, status: 'available', used_at: nil) }
    booking.update!(discount_amount: 0, eco_discount: {}) unless preserve
    booking.association(:eco_redemption).reset
  end

  def self.release_expired_holds!(user)
    user.bookings.joins(:eco_redemption).where(payment_status: 'pending').where('hold_expires_at <= ?', Time.current).find_each do |booking|
      booking.with_lock { release!(booking, preserve: false) if booking.trail_hold_expired? }
    end
  end

  def self.validate!(booking, voucher)
    valid_status = voucher.status == 'available' || (voucher.status == 'reserved' && voucher.booking_id == booking.id)
    unless valid_status && voucher.expires_at.future? && voucher.user_id == booking.user_id && voucher.benefit['scope'] == scope_for(booking)
      raise Invalid, 'Este cupom já foi usado, expirou ou não se aplica à reserva.'
    end
  end
  private_class_method :validate!
end
