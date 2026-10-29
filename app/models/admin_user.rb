class AdminUser < ApplicationRecord
  has_secure_password
  has_many :admin_audits, dependent: :restrict_with_error
  belongs_to :eco_collection_point, optional: true
  before_validation { self.email = email.to_s.strip.downcase }
  before_update :invalidate_changed_credentials
  validates :name, :email, presence: true
  validates :name, length: { maximum: 120 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ['admin', 'suporte', 'operador_coleta'] }
  validates :eco_collection_point, presence: true, if: :collection_operator?
  validates :password, length: { minimum: 12, maximum: 72 }, allow_nil: true
  validate :preserve_last_administrator, on: :update

  def admin?
    role == 'admin'
  end

  def suporte?
    role == 'suporte'
  end

  def collection_operator?
    role == 'operador_coleta'
  end

  private

  def invalidate_changed_credentials
    self.session_version += 1 if will_save_change_to_password_digest? || will_save_change_to_active? || will_save_change_to_role? || will_save_change_to_eco_collection_point_id?
  end

  def preserve_last_administrator
    return unless role_in_database == 'admin' && active_in_database && (role != 'admin' || !active?)
    errors.add(:base, 'Mantenha ao menos um administrador ativo') unless AdminUser.where(role: 'admin', active: true).where.not(id: id).exists?
  end
end
