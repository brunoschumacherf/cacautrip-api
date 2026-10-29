class Alert < ApplicationRecord
  validates :title, :body, :kind, presence: true
  scope :current, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
end
