class Trail < ApplicationRecord
  belongs_to :guide_profile
  has_many :stops, -> { order(:position, :id) }, class_name: 'TrailStop', dependent: :destroy, inverse_of: :trail
  has_many :departures, class_name: 'TrailDeparture', dependent: :restrict_with_error
  accepts_nested_attributes_for :stops, allow_destroy: true
  validates :title, :description, :region, presence: true
  validates :title, length: { maximum: 150 }
  validates :status, inclusion: { in: ['draft', 'published', 'archived', 'hidden'] }
  validates :route_mode, inclusion: { in: ['ordered', 'flexible'] }
  validates :difficulty, inclusion: { in: ['easy', 'moderate', 'hard'] }
  validates :price_mode, inclusion: { in: ['per_person', 'group'] }
  validates :price, numericality: { greater_than: 0 }
  validates :distance_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10080 }
  validates :minimum_age, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :image_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  validate :publishing_requirements

  scope :visible, -> { joins(guide_profile: :user).where(status: 'published', guide_profiles: { moderation_status: 'published', available: true }, users: { gov_verified: true, suspended: false }) }

  def published?
    status == 'published'
  end

  def serialize(owner: false)
    upcoming = departures.where(status: 'scheduled').where('starts_at > ?', Time.current).order(:starts_at)
    reviews = Review.where(booking_id: Booking.where(trail_departure_id: departures.select(:id)).select(:id), hidden: false)
    as_json.merge('stops' => stops.reject(&:marked_for_destruction?).as_json,
      'guide' => { id: guide_profile.id, user_id: guide_profile.user_id, name: guide_profile.user.name, image_url: guide_profile.image_url, languages: guide_profile.languages },
      'departures' => (owner ? departures.order(:starts_at) : upcoming).map(&:serialize),
      'rating' => reviews.average(:rating)&.to_f&.round(1) || 0,
      'reviews_count' => reviews.count, 'reviews' => reviews.order(created_at: :desc).limit(20).map { |review| review.as_json.merge('author' => review.user.name) })
  end

  private

  def publishing_requirements
    return unless published?
    errors.add(:base, 'O guia precisa estar aprovado para publicar trilhas') unless guide_profile&.moderation_status == 'published' && guide_profile&.user&.gov_verified? && !guide_profile.user.suspended?
    valid_stops = stops.reject(&:marked_for_destruction?)
    errors.add(:base, 'Cadastre pelo menos dois pontos de passagem antes de publicar') if valid_stops.length < 2
    errors.add(:base, 'Uma trilha pode ter até 50 pontos') if valid_stops.length > 50
  end
end
