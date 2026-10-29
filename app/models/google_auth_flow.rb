require 'digest'
class GoogleAuthFlow < ApplicationRecord
  belongs_to :link_user, class_name: 'User', optional: true
  belongs_to :authenticated_user, class_name: 'User', optional: true

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end
end
