class WalletEntry < ApplicationRecord
  belongs_to :user
  belongs_to :booking, optional: true
  validates :amount, numericality: true
  validates :kind, inclusion: { in: ['earning', 'payout', 'subscription'] }
end
