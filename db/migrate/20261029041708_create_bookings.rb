class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :service_type
      t.integer :service_id
      t.decimal :total_amount, precision: 10, scale: 2
      t.string :status, default: 'pending'
      t.string :payment_status, default: 'pending'
      t.string :payment_method

      t.timestamps
    end
  end
end