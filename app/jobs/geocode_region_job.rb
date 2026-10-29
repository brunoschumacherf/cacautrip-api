class GeocodeRegionJob < ApplicationJob
  def perform(city)
    AddressGeocoder.resolve("#{city}, Bahia, Brasil", city: city, area: true)
  end
end
