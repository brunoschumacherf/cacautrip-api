class CreateSustainabilityProgram < ActiveRecord::Migration[7.1]
  def change
    create_table :eco_collection_points do |t|
      t.string :name, null: false
      t.string :city, null: false
      t.string :address, null: false
      t.text :description
      t.string :materials
      t.string :opening_hours
      t.string :image_url
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    create_table :eco_partners do |t|
      t.string :name, null: false
      t.string :city, null: false
      t.string :address, null: false
      t.text :description
      t.string :image_url
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_reference :admin_users, :eco_collection_point, foreign_key: true
    add_column :users, :eco_points, :integer, default: 0, null: false
    add_check_constraint :users, 'eco_points >= 0', name: 'eco_points_nonnegative'
    create_table :eco_rewards do |t|
      t.references :eco_partner, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :image_url
      t.string :scope, null: false
      t.string :discount_type, default: 'fixed', null: false
      t.decimal :discount_value, precision: 12, scale: 2, null: false
      t.decimal :minimum_amount, precision: 12, scale: 2, default: 0, null: false
      t.decimal :maximum_discount, precision: 12, scale: 2
      t.integer :points_cost, null: false
      t.integer :stock
      t.datetime :expires_at
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_check_constraint :eco_rewards, 'stock IS NULL OR stock >= 0', name: 'eco_reward_stock_nonnegative'
    create_table :eco_collection_codes do |t|
      t.references :eco_collection_point, null: false, foreign_key: true
      t.references :issuer, null: false, foreign_key: { to_table: :admin_users }
      t.references :claimed_by, foreign_key: { to_table: :users }
      t.string :code, null: false
      t.integer :points, null: false
      t.datetime :expires_at, null: false
      t.datetime :claimed_at
      t.datetime :voided_at
      t.timestamps
    end
    add_index :eco_collection_codes, :code, unique: true
    create_table :eco_redemptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :eco_reward, null: false, foreign_key: true
      t.references :booking, foreign_key: true, index: { unique: true }
      t.references :validated_by, foreign_key: { to_table: :admin_users }
      t.string :code, null: false
      t.string :status, default: 'available', null: false
      t.string :request_key, null: false
      t.jsonb :benefit, default: {}, null: false
      t.integer :points_cost, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :eco_redemptions, :code, unique: true
    add_index :eco_redemptions, [:user_id, :request_key], unique: true
    create_table :eco_point_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :eco_collection_code, foreign_key: true, index: { unique: true }
      t.references :eco_redemption, foreign_key: true, index: { unique: true }
      t.integer :amount, null: false
      t.string :description, null: false
      t.timestamps
    end
    add_column :bookings, :discount_amount, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :bookings, :eco_discount, :jsonb, default: {}, null: false
    add_check_constraint :bookings, 'discount_amount >= 0 AND discount_amount <= total_amount', name: 'booking_discount_within_total'
  end
end
