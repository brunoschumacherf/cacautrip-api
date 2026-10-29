class SystemIncident < ApplicationRecord
  validates :error_class, presence: true
  validates :status, inclusion: { in: ['open', 'investigating', 'resolved'] }
end
