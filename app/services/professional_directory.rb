class ProfessionalDirectory
  def self.serialize(profile, private_fields: false)
    type = profile.is_a?(GuideProfile) ? 'Guia' : 'Motorista'
    reviews = Review.where(booking_id: Booking.where(service_type: type, service_id: profile.id).select(:id), hidden: false)
    subscription = Subscription.find_by(user_id: profile.user_id, professional_type: type == 'Guia' ? 'guide' : 'driver', status: 'active')
    data = profile.as_json
    data.except!('document_reference', 'license_plate') unless private_fields
    data.merge(name: profile.user.name, verified: profile.user.gov_verified?, documents_verified: type == 'Guia' ? profile.verified_documents : profile.verified_cnh,
      trails_count: profile.is_a?(GuideProfile) ? profile.trails.where(status: 'published').count : 0,
      starting_price: profile.is_a?(GuideProfile) ? profile.trails.where(status: 'published').minimum(:price)&.to_f : nil,
      rating: reviews.average(:rating)&.round(1) || 0, reviews_count: reviews.count,
      reviews: reviews.order(created_at: :desc).limit(30).map { |review| review.as_json.merge(author: review.user.name) },
      plan: subscription && subscription.renews_at && subscription.renews_at > Time.current ? subscription.plan : 'basic')
  end
end
