module GeocodablePlace
  extend ActiveSupport::Concern
  included do
    before_validation :reset_changed_address
    after_commit :queue_address_coordinates, on: [:create, :update]
  end

  def geocoding_city
    has_attribute?(:city) ? city.to_s : (respond_to?(:trail) ? trail.region.to_s.split(/[,;\/]/).first.to_s : 'Ilhéus')
  end

  def geocoding_queries
    place = has_attribute?(:address) && address.present? ? address.to_s : name.to_s
    city = geocoding_city
    full = [place, city, 'Bahia', 'Brasil'].reject(&:blank?).join(', ')
    # Rua sem número é uma aproximação real do logradouro, nunca o centro da cidade.
    street = place.split(',').first.to_s
    named = [name, city, 'Bahia', 'Brasil'].join(', ') if is_a?(EmergencyPoint)
    [named, full, ([street, city, 'Bahia', 'Brasil'].join(', ') if has_attribute?(:address))].compact.uniq
  end

  private

  def reset_changed_address
    fields = has_attribute?(:address) ? %w[address city] : %w[name city]
    changed = fields.any? { |field| has_attribute?(field) && will_save_change_to_attribute?(field) }
    if persisted? && changed && !will_save_change_to_latitude? && !will_save_change_to_longitude?
      self.latitude = self.longitude = nil
    end
    self.geocoding_approximate = false if will_save_change_to_latitude? || will_save_change_to_longitude?
  end

  def queue_address_coordinates
    return if latitude.present? && longitude.present?
    GeocodePlaceJob.perform_later(self.class.name, id)
  end
end
