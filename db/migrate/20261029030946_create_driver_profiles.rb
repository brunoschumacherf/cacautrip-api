class CreateDriverProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :driver_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :vehicle_model
      t.string :license_plate
      t.integer :capacity
      t.boolean :verified_cnh, default: false
      t.string :subscription_plan

      t.timestamps
    end
  end
end
