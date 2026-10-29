class EcoPointEntry < ApplicationRecord
  belongs_to :user
  belongs_to :eco_collection_code, optional: true
  belongs_to :eco_redemption, optional: true
  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :description, presence: true
end
