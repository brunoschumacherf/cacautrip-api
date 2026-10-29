class CreateAdministrativeBackoffice < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, default: 'suporte', null: false
      t.boolean :active, default: true, null: false
      t.integer :session_version, default: 1, null: false
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :admin_users, 'lower(email)', unique: true, name: 'index_admin_users_on_lower_email'
    create_table :admin_audits do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :record_type
      t.bigint :record_id
      t.jsonb :metadata, default: {}, null: false
      t.string :request_id
      t.timestamps
    end
    add_index :admin_audits, [:record_type, :record_id]
    create_table :system_incidents do |t|
      t.string :error_class, null: false
      t.string :location
      t.string :request_id
      t.text :trace
      t.string :status, default: 'open', null: false
      t.text :resolution
      t.timestamps
    end
    add_index :system_incidents, [:status, :created_at]
  end
end
