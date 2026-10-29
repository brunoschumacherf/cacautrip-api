class GuideProfile < ApplicationRecord
  belongs_to :user
  has_many :trails, dependent: :restrict_with_error
  validates :specialization, :languages, :description, :image_url, :document_reference, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :moderation_status, inclusion: { in: ['pending', 'published', 'rejected', 'hidden'] }
  validates :image_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
end
