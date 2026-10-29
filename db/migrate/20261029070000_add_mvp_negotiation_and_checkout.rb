class AddMvpNegotiationAndCheckout < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :offer_by_id, :bigint
    add_foreign_key :bookings, :users, column: :offer_by_id
    add_column :bookings, :offer_history, :jsonb, default: [], null: false
    add_column :bookings, :pickup_latitude, :float
    add_column :bookings, :pickup_longitude, :float
    add_column :bookings, :dropoff_latitude, :float
    add_column :bookings, :dropoff_longitude, :float
    add_column :wallet_entries, :reference, :string
    add_column :wallet_entries, :metadata, :jsonb, default: {}, null: false
    add_index :wallet_entries, [:user_id, :reference], unique: true
    create_table :subscription_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :professional_type, null: false
      t.string :plan, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.boolean :auto_renew, default: false, null: false
      t.string :status, default: 'pending', null: false
      t.string :payment_method
      t.integer :payment_polls, default: 0, null: false
      t.datetime :paid_at
      t.timestamps
    end
  end
end
