class TrailDeparture < ApplicationRecord
  belongs_to :trail
  has_many :bookings, dependent: :restrict_with_error
  validates :starts_at, :meeting_point, presence: true
  validates :starts_at, uniqueness: { scope: :trail_id }
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :price_override, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: ['scheduled', 'cancelled', 'finished'] }
  validate :protect_existing_reservations
  validate :no_overlapping_departure

  def occupying_bookings
    bookings.where(status: ['confirmed', 'completed']).or(
      bookings.where(status: ['pending_approval', 'approved_waiting_payment']).where('hold_expires_at IS NULL OR hold_expires_at > ?', Time.current))
  end

  def available_seats
    [capacity - occupying_bookings.sum(:people), 0].max
  end

  def unit_price
    price_override || trail.price
  end

  def serialize
    as_json.merge('available_seats' => available_seats, 'unit_price' => unit_price.to_f, 'price_mode' => trail.price_mode,
      'ends_at' => starts_at && starts_at + trail.duration_minutes.minutes)
  end

  private

  def no_overlapping_departure
    return unless status == 'scheduled' && starts_at && trail && (new_record? || will_save_change_to_starts_at?)
    other_departures = TrailDeparture.where(trail_id: Trail.where(guide_profile_id: trail.guide_profile_id).select(:id), status: 'scheduled').where.not(id: id)
      .where('starts_at < ?', starts_at + trail.duration_minutes.minutes).includes(:trail)
    if other_departures.any? { |other| other.starts_at + other.trail.duration_minutes.minutes > starts_at }
      errors.add(:starts_at, 'coincide com outra saída deste guia')
    end
  end

  def protect_existing_reservations
    return if new_record?
    occupied = occupying_bookings.sum(:people)
    errors.add(:capacity, 'não pode ser menor que o número de vagas já reservado') if capacity && capacity < occupied
    errors.add(:starts_at, 'não pode ser alterado em uma saída com reservas. Cancele a saída e crie outra data.') if will_save_change_to_starts_at? && occupied.positive?
    errors.add(:meeting_point, 'não pode ser alterado em uma saída com reservas. Avise os participantes pelo chat.') if will_save_change_to_meeting_point? && occupied.positive?
  end
end
