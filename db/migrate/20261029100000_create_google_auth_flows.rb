class CreateGoogleAuthFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :google_auth_flows do |t|
      t.string :state_digest, null: false
      t.string :exchange_digest, null: false
      t.string :nonce, null: false
      t.string :redirect_uri, null: false
      t.references :link_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :authenticated_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :ticket_digest
      t.string :status, default: 'pending', null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :google_auth_flows, :state_digest, unique: true
    add_index :google_auth_flows, :ticket_digest, unique: true
    add_index :users, :google_uid, unique: true, where: 'google_uid IS NOT NULL'
  end
end
