class AdminAudit < ApplicationRecord
  belongs_to :admin_user
  validates :action, presence: true
end
