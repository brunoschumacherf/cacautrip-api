class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :route, optional: true
  belongs_to :trail_departure, optional: true
  has_one :review
  has_many :wallet_entries
  has_one :eco_redemption
  TYPES = { 'Guia' => 'GuideProfile', 'Motorista' => 'DriverProfile', 'Passeio' => 'Destination', 'Parceiro' => 'Destination' }.freeze
  validates :service_type, inclusion: { in: TYPES.keys }
  validates :total_amount, numericality: { greater_than: 0 }
  validates :people, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :date, :meeting_point, presence: true
  validate :valid_date
  validate :negotiation_safety
  validates :pickup_latitude, :dropoff_latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :pickup_longitude, :dropoff_longitude, numericality: { in: -180..180 }, allow_nil: true
  after_create_commit :notify_proposal
  after_update_commit :notify_status

  def professional_profile
    TYPES[service_type]&.constantize&.find_by(id: service_id)
  end

  def provider
    profile = professional_profile
    profile.is_a?(Destination) ? profile.provider : profile&.user
  end

  def details
    profile = professional_profile
    as_json.merge(professional: profile&.as_json&.except('document_reference')&.merge('name' => provider&.name || profile.try(:name)),
      provider_id: provider&.id, tourist_name: user.name, review: review, fee_rate: PlatformSetting.commission.to_f,
      itinerary: trail_snapshot.present? ? trail_snapshot.fetch('stops', []) : route&.preferences.to_h.fetch('itinerary', []),
      hold_expired: trail_hold_expired?, commission: commission_breakdown, amount_due: amount_due.to_f,
      platform_net_amount: (fee_amount.to_d - discount_amount).to_f)
  end

  def amount_due
    total_amount - discount_amount
  end

  def commission_breakdown
    if ['approved', 'refunded'].include?(payment_status)
      { gross: total_amount.to_f, fee: fee_amount.to_f, net: professional_amount.to_f, percent: nil, estimated: false }
    else
      CommissionQuote.call(total_amount || 0)
    end
  end

  def trail_hold_expired?
    trail_departure_id.present? && payment_status != 'approved' && hold_expires_at.present? && hold_expires_at <= Time.current
  end

  def approve_payment!
    return if payment_status == 'approved'
    EcoCheckout.consume!(self)
    fee = (total_amount * PlatformSetting.commission).round(2)
    update!(status: 'confirmed', payment_status: 'approved', fee_amount: fee, professional_amount: total_amount - fee)
    if provider
      WalletEntry.create!(booking: self, user: provider, kind: 'earning', amount: professional_amount, status: 'pending')
    end
  end

  private

  def negotiation_safety
    errors.add(:conditions, 'não pode incluir dados de contato externo') if ContactPolicy.blocked?(conditions)
  end

  def valid_date
    Time.zone.parse(date.to_s)
  rescue ArgumentError, TypeError
    errors.add(:date, 'deve conter uma data válida')
  end

  def notify_proposal
    Notification.create!(user: provider, title: 'Nova proposta de reserva', body: "#{user.name} solicitou #{service_type} em #{date}", kind: 'booking', target: 'agenda') if provider
  end

  def notify_status
    return unless saved_change_to_status? || saved_change_to_total_amount?
    [user, provider].compact.uniq.each do |recipient|
      Notification.create!(user: recipient, title: 'Reserva atualizada', body: "Reserva ##{id}: #{status}", kind: 'booking', target: 'reservas')
    end
  end
end
