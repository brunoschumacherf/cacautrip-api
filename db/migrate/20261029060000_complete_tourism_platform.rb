class CompleteTourismPlatform < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :active_role, :string, default: 'tourist'
    add_column :users, :preferences, :jsonb, default: {}, null: false
    add_column :users, :google_uid, :string
    add_column :users, :suspended, :boolean, default: false
    [:guide_profiles, :driver_profiles].each do |table|
      add_column table, :region, :string
      add_column table, :price, :decimal, precision: 10, scale: 2, default: 0
      add_column table, :available, :boolean, default: true
      add_column table, :accessible, :boolean, default: false
      add_column table, :services, :text
      add_column table, :document_reference, :string
      add_column table, :availability, :jsonb, default: []
      add_column table, :moderation_status, :string, default: 'published'
    end
    add_column :driver_profiles, :description, :text
    add_column :driver_profiles, :image_url, :string
    add_reference :bookings, :route, foreign_key: true
    add_column :bookings, :people, :integer, default: 1
    add_column :bookings, :dropoff_point, :string
    add_column :bookings, :completed_at, :datetime
    add_column :bookings, :fee_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :bookings, :professional_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :bookings, :conditions, :text
    add_column :routes, :shared_token, :string
    add_index :routes, :shared_token, unique: true
    create_table :destinations do |t|
      t.references :provider, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :category, null: false
      t.string :city
      t.text :description
      t.string :image_url
      t.float :latitude
      t.float :longitude
      t.decimal :price, precision: 10, scale: 2, default: 0
      t.integer :duration_minutes, default: 60
      t.string :opening_hours
      t.text :rules
      t.boolean :accessible, default: false
      t.boolean :guide_required, default: false
      t.boolean :active, default: true
      t.string :best_time
      t.timestamps
    end
    create_table :emergency_points do |t|
      t.string :name, null: false
      t.string :category
      t.string :phone
      t.string :address
      t.float :latitude
      t.float :longitude
      t.timestamps
    end
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.string :kind
      t.string :target
      t.datetime :read_at
      t.timestamps
    end
    create_table :alerts do |t|
      t.string :title, null: false
      t.text :body
      t.string :kind
      t.string :region
      t.string :source_url
      t.datetime :expires_at
      t.timestamps
    end
    create_table :reviews do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment
      t.boolean :hidden, default: false
      t.timestamps
    end
    create_table :reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :reason, null: false
      t.string :status, default: 'open'
      t.timestamps
    end
    create_table :support_tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.text :message, null: false
      t.text :reply
      t.string :status, default: 'open'
      t.timestamps
    end
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :professional_type, null: false
      t.string :plan, null: false
      t.string :status, default: 'active'
      t.datetime :renews_at
      t.boolean :auto_renew, default: false
      t.timestamps
    end
    add_index :subscriptions, [:user_id, :professional_type], unique: true
    create_table :wallet_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :booking, foreign_key: true
      t.string :kind, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending'
      t.timestamps
    end
    add_index :wallet_entries, [:booking_id, :kind], unique: true
    create_table :platform_settings do |t|
      t.string :key, null: false
      t.jsonb :value, default: {}
      t.timestamps
    end
    add_index :platform_settings, :key, unique: true
    add_reference :conversations, :booking, foreign_key: true
    add_column :messages, :hidden, :boolean, default: false, null: false
  end
end
