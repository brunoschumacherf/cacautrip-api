class AddAddressGeocoding < ActiveRecord::Migration[7.1]
  def change
    create_table :geocoded_addresses do |t|
      t.string :fingerprint, null: false
      t.text :query, null: false
      t.string :status, default: 'pending', null: false
      t.jsonb :result, default: {}, null: false
      t.datetime :requested_at
      t.timestamps
    end
    add_index :geocoded_addresses, :fingerprint, unique: true
    add_column :eco_partners, :latitude, :decimal, precision: 10, scale: 7
    add_column :eco_partners, :longitude, :decimal, precision: 10, scale: 7
    %i[eco_collection_points eco_partners destinations trail_stops emergency_points].each do |table|
      add_column table, :geocoding_approximate, :boolean, default: false, null: false
    end
  end
end
