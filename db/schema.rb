# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_10_29_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_audits", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "action", null: false
    t.string "record_type"
    t.bigint "record_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_admin_audits_on_admin_user_id"
    t.index ["record_type", "record_id"], name: "index_admin_audits_on_record_type_and_record_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "suporte", null: false
    t.boolean "active", default: true, null: false
    t.integer "session_version", default: 1, null: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_admin_users_on_lower_email", unique: true
  end

  create_table "alerts", force: :cascade do |t|
    t.string "title", null: false
    t.text "body"
    t.string "kind"
    t.string "region"
    t.string "source_url"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "service_type"
    t.integer "service_id"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "status", default: "pending"
    t.string "payment_status", default: "pending"
    t.string "payment_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "date"
    t.string "meeting_point"
    t.integer "payment_polls", default: 0, null: false
    t.bigint "route_id"
    t.integer "people", default: 1
    t.string "dropoff_point"
    t.datetime "completed_at"
    t.decimal "fee_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "professional_amount", precision: 10, scale: 2, default: "0.0"
    t.text "conditions"
    t.bigint "offer_by_id"
    t.jsonb "offer_history", default: [], null: false
    t.float "pickup_latitude"
    t.float "pickup_longitude"
    t.float "dropoff_latitude"
    t.float "dropoff_longitude"
    t.bigint "trail_departure_id"
    t.jsonb "trail_snapshot", default: {}, null: false
    t.datetime "hold_expires_at"
    t.index ["route_id"], name: "index_bookings_on_route_id"
    t.index ["trail_departure_id"], name: "index_bookings_on_trail_departure_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "tourist_id", null: false
    t.bigint "guide_id"
    t.bigint "driver_id"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "booking_id"
    t.index ["booking_id"], name: "index_conversations_on_booking_id"
    t.index ["driver_id"], name: "index_conversations_on_driver_id"
    t.index ["guide_id"], name: "index_conversations_on_guide_id"
    t.index ["tourist_id"], name: "index_conversations_on_tourist_id"
  end

  create_table "destinations", force: :cascade do |t|
    t.bigint "provider_id"
    t.string "name", null: false
    t.string "category", null: false
    t.string "city"
    t.text "description"
    t.string "image_url"
    t.float "latitude"
    t.float "longitude"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.integer "duration_minutes", default: 60
    t.string "opening_hours"
    t.text "rules"
    t.boolean "accessible", default: false
    t.boolean "guide_required", default: false
    t.boolean "active", default: true
    t.string "best_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_destinations_on_provider_id"
  end

  create_table "driver_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "vehicle_model"
    t.string "license_plate"
    t.integer "capacity"
    t.boolean "verified_cnh", default: false
    t.string "subscription_plan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "region"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.boolean "available", default: true
    t.boolean "accessible", default: false
    t.text "services"
    t.string "document_reference"
    t.jsonb "availability", default: []
    t.string "moderation_status", default: "published"
    t.text "description"
    t.string "image_url"
    t.index ["user_id"], name: "index_driver_profiles_on_user_id"
  end

  create_table "emergency_points", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.string "phone"
    t.string "address"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_auth_flows", force: :cascade do |t|
    t.string "state_digest", null: false
    t.string "exchange_digest", null: false
    t.string "nonce", null: false
    t.string "redirect_uri", null: false
    t.bigint "link_user_id"
    t.bigint "authenticated_user_id"
    t.string "ticket_digest"
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authenticated_user_id"], name: "index_google_auth_flows_on_authenticated_user_id"
    t.index ["link_user_id"], name: "index_google_auth_flows_on_link_user_id"
    t.index ["state_digest"], name: "index_google_auth_flows_on_state_digest", unique: true
    t.index ["ticket_digest"], name: "index_google_auth_flows_on_ticket_digest", unique: true
  end

  create_table "guide_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "specialization"
    t.text "languages"
    t.boolean "verified_documents", default: false
    t.string "subscription_plan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "region"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.boolean "available", default: true
    t.boolean "accessible", default: false
    t.text "services"
    t.string "document_reference"
    t.jsonb "availability", default: []
    t.string "moderation_status", default: "published"
    t.index ["user_id"], name: "index_guide_profiles_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "sender_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden", default: false, null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "kind"
    t.string "target"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "platform_settings", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "value", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_platform_settings_on_key", unique: true
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.text "reason", null: false
    t.string "status", default: "open"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.boolean "hidden", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_reviews_on_booking_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "routes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.string "destination"
    t.decimal "budget"
    t.decimal "total_estimated_cost"
    t.jsonb "preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "shared_token"
    t.index ["shared_token"], name: "index_routes_on_shared_token", unique: true
    t.index ["user_id"], name: "index_routes_on_user_id"
  end

  create_table "subscription_orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "professional_type", null: false
    t.string "plan", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.boolean "auto_renew", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "payment_method"
    t.integer "payment_polls", default: 0, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_subscription_orders_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "professional_type", null: false
    t.string "plan", null: false
    t.string "status", default: "active"
    t.datetime "renews_at"
    t.boolean "auto_renew", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "professional_type"], name: "index_subscriptions_on_user_id_and_professional_type", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "support_messages", force: :cascade do |t|
    t.bigint "support_ticket_id", null: false
    t.bigint "admin_user_id"
    t.string "role", null: false
    t.string "sender_name"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_support_messages_on_admin_user_id"
    t.index ["support_ticket_id", "id"], name: "index_support_messages_on_support_ticket_id_and_id"
    t.index ["support_ticket_id"], name: "index_support_messages_on_support_ticket_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "message", null: false
    t.text "reply"
    t.string "status", default: "ai"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "human_requested_at"
    t.string "ai_request_id"
    t.datetime "ai_started_at"
    t.bigint "assigned_staff_id"
    t.index ["assigned_staff_id"], name: "index_support_tickets_on_assigned_staff_id"
    t.index ["status", "updated_at"], name: "index_support_tickets_on_status_and_updated_at"
    t.index ["user_id"], name: "index_support_tickets_on_user_id"
  end

  create_table "system_incidents", force: :cascade do |t|
    t.string "error_class", null: false
    t.string "location"
    t.string "request_id"
    t.text "trace"
    t.string "status", default: "open", null: false
    t.text "resolution"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "created_at"], name: "index_system_incidents_on_status_and_created_at"
  end

  create_table "trail_departures", force: :cascade do |t|
    t.bigint "trail_id", null: false
    t.datetime "starts_at", null: false
    t.integer "capacity", null: false
    t.decimal "price_override", precision: 10, scale: 2
    t.string "meeting_point", null: false
    t.text "notes"
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trail_id", "starts_at"], name: "index_trail_departures_on_trail_id_and_starts_at", unique: true
    t.index ["trail_id"], name: "index_trail_departures_on_trail_id"
  end

  create_table "trail_stops", force: :cascade do |t|
    t.bigint "trail_id", null: false
    t.string "name", null: false
    t.string "address", null: false
    t.text "description"
    t.string "kind", default: "visit", null: false
    t.integer "position", default: 0, null: false
    t.integer "duration_minutes", default: 15, null: false
    t.float "latitude"
    t.float "longitude"
    t.boolean "optional", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trail_id", "position"], name: "index_trail_stops_on_trail_id_and_position"
    t.index ["trail_id"], name: "index_trail_stops_on_trail_id"
  end

  create_table "trails", force: :cascade do |t|
    t.bigint "guide_profile_id", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.string "region", null: false
    t.string "image_url"
    t.string "difficulty", default: "easy", null: false
    t.string "route_mode", default: "ordered", null: false
    t.string "status", default: "draft", null: false
    t.integer "duration_minutes", default: 180, null: false
    t.decimal "distance_km", precision: 8, scale: 2
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "price_mode", default: "per_person", null: false
    t.integer "minimum_age", default: 0, null: false
    t.boolean "accessible", default: false, null: false
    t.text "included"
    t.text "not_included"
    t.text "what_to_bring"
    t.text "safety_notes"
    t.text "cancellation_policy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guide_profile_id"], name: "index_trails_on_guide_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.boolean "gov_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "active_role", default: "tourist"
    t.jsonb "preferences", default: {}, null: false
    t.string "google_uid"
    t.boolean "suspended", default: false
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true, where: "(google_uid IS NOT NULL)"
  end

  create_table "wallet_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "booking_id"
    t.string "kind", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reference"
    t.jsonb "metadata", default: {}, null: false
    t.index ["booking_id", "kind"], name: "index_wallet_entries_on_booking_id_and_kind", unique: true
    t.index ["booking_id"], name: "index_wallet_entries_on_booking_id"
    t.index ["user_id", "reference"], name: "index_wallet_entries_on_user_id_and_reference", unique: true
    t.index ["user_id"], name: "index_wallet_entries_on_user_id"
  end

  add_foreign_key "admin_audits", "admin_users"
  add_foreign_key "bookings", "routes"
  add_foreign_key "bookings", "trail_departures"
  add_foreign_key "bookings", "users"
  add_foreign_key "bookings", "users", column: "offer_by_id"
  add_foreign_key "conversations", "bookings"
  add_foreign_key "conversations", "users", column: "driver_id"
  add_foreign_key "conversations", "users", column: "guide_id"
  add_foreign_key "conversations", "users", column: "tourist_id"
  add_foreign_key "destinations", "users", column: "provider_id"
  add_foreign_key "driver_profiles", "users"
  add_foreign_key "google_auth_flows", "users", column: "authenticated_user_id", on_delete: :nullify
  add_foreign_key "google_auth_flows", "users", column: "link_user_id", on_delete: :nullify
  add_foreign_key "guide_profiles", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "reports", "users"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "users"
  add_foreign_key "routes", "users"
  add_foreign_key "subscription_orders", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "support_messages", "admin_users", on_delete: :nullify
  add_foreign_key "support_messages", "support_tickets"
  add_foreign_key "support_tickets", "admin_users", column: "assigned_staff_id", on_delete: :nullify
  add_foreign_key "support_tickets", "users"
  add_foreign_key "trail_departures", "trails"
  add_foreign_key "trail_stops", "trails"
  add_foreign_key "trails", "guide_profiles"
  add_foreign_key "wallet_entries", "bookings"
  add_foreign_key "wallet_entries", "users"
end
