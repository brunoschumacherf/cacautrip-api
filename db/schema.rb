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

ActiveRecord::Schema[7.1].define(version: 2026_10_29_030947) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "driver_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "vehicle_model"
    t.string "license_plate"
    t.integer "capacity"
    t.boolean "verified_cnh", default: false
    t.string "subscription_plan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_driver_profiles_on_user_id"
  end

  create_table "guide_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "specialization"
    t.text "languages"
    t.boolean "verified_documents", default: false
    t.string "subscription_plan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_guide_profiles_on_user_id"
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
    t.index ["user_id"], name: "index_routes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.boolean "gov_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "driver_profiles", "users"
  add_foreign_key "guide_profiles", "users"
  add_foreign_key "routes", "users"
end
