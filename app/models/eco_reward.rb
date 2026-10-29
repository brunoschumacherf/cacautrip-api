class EcoReward < ApplicationRecord
  belongs_to :eco_partner, optional: true
  has_many :eco_redemptions, dependent: :restrict_with_error
  validates :title, presence: true, length: { maximum: 150 }
  validates :image_url, length: { maximum: 255 }, allow_blank: true
  validates :scope, inclusion: { in: %w[partner trail driver] }
  validates :discount_type, inclusion: { in: %w[fixed percent] }
  validates :discount_value, numericality: { greater_than: 0, less_than_or_equal_to: 1000000 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: -> { discount_type == 'percent' }
  validates :minimum_amount, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000 }
  validates :maximum_discount, numericality: { greater_than: 0, less_than_or_equal_to: 1000000 }, allow_nil: true
  validates :points_cost, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1000000 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000 }, allow_nil: true
  validates :eco_partner, presence: true, if: -> { scope == 'partner' }
  validates :image_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  scope :available, -> { where(active: true).where('eco_rewards.expires_at IS NULL OR eco_rewards.expires_at > ?', Time.current).where('stock IS NULL OR stock > 0').where("scope <> 'partner' OR eco_partner_id IN (SELECT id FROM eco_partners WHERE active = true)") }

  def benefit_snapshot
    { title: title, description: description, scope: scope, discount_type: discount_type,
      discount_value: discount_value.to_f, minimum_amount: minimum_amount.to_f,
      maximum_discount: maximum_discount&.to_f, partner: eco_partner&.as_json(only: [:name, :city, :address]),
      image_url: image_url.presence || eco_partner&.image_url }.stringify_keys
  end

  def public_reward
    benefit_snapshot.merge(id: id, points_cost: points_cost, stock: stock, expires_at: expires_at)
  end
end
