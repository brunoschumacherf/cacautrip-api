class ProfilePhoto < ApplicationRecord
  MAX_BYTES = 2.megabytes
  TYPES = %w[image/jpeg image/png image/webp].freeze
  belongs_to :user
  validates :image_data, :version, presence: true
  validates :content_type, inclusion: { in: TYPES }
  validate do
    errors.add(:base, 'A foto deve ter no máximo 2 MB.') if image_data && image_data.bytesize > MAX_BYTES
  end

  def url_path
    "/profile_photos/#{signed_id(purpose: 'profile_photo')}?version=#{version}"
  end
end
