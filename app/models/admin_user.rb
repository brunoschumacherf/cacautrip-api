class AdminUser < ApplicationRecord
  has_secure_password
  has_many :admin_audits, dependent: :restrict_with_error
  before_validation { self.email = email.to_s.strip.downcase }
  before_update :invalidate_changed_credentials
  validates :name, :email, presence: true
  validates :name, length: { maximum: 120 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ['admin', 'suporte'] }
  validates :password, length: { minimum: 12, maximum: 72 }, allow_nil: true
  validate :preserve_last_administrator, on: :update

  def admin?
    role == 'admin'
  end

  def suporte?
    role == 'suporte'
  end

  private

  def invalidate_changed_credentials
    self.session_version += 1 if will_save_change_to_password_digest? || will_save_change_to_active? || will_save_change_to_role?
  end

  def preserve_last_administrator
    return unless role_in_database == 'admin' && active_in_database && (role != 'admin' || !active?)
    errors.add(:base, 'Mantenha ao menos um administrador ativo') unless AdminUser.where(role: 'admin', active: true).where.not(id: id).exists?
  end
end
