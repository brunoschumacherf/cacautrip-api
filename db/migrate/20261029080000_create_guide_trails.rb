class CreateGuideTrails < ActiveRecord::Migration[7.1]
  def change
    create_table :trails do |t|
      t.references :guide_profile, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.string :region, null: false
      t.string :image_url
      t.string :difficulty, default: 'easy', null: false
      t.string :route_mode, default: 'ordered', null: false
      t.string :status, default: 'draft', null: false
      t.integer :duration_minutes, default: 180, null: false
      t.decimal :distance_km, precision: 8, scale: 2
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :price_mode, default: 'per_person', null: false
      t.integer :minimum_age, default: 0, null: false
      t.boolean :accessible, default: false, null: false
      t.text :included
      t.text :not_included
      t.text :what_to_bring
      t.text :safety_notes
      t.text :cancellation_policy
      t.timestamps
    end
    create_table :trail_stops do |t|
      t.references :trail, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address, null: false
      t.text :description
      t.string :kind, default: 'visit', null: false
      t.integer :position, default: 0, null: false
      t.integer :duration_minutes, default: 15, null: false
      t.float :latitude
      t.float :longitude
      t.boolean :optional, default: false, null: false
      t.timestamps
    end
    add_index :trail_stops, [:trail_id, :position]
    create_table :trail_departures do |t|
      t.references :trail, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.integer :capacity, null: false
      t.decimal :price_override, precision: 10, scale: 2
      t.string :meeting_point, null: false
      t.text :notes
      t.string :status, default: 'scheduled', null: false
      t.timestamps
    end
    add_index :trail_departures, [:trail_id, :starts_at], unique: true
    add_reference :bookings, :trail_departure, foreign_key: true
    add_column :bookings, :trail_snapshot, :jsonb, default: {}, null: false
    add_column :bookings, :hold_expires_at, :datetime
  end
end
