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

ActiveRecord::Schema[8.1].define(version: 2026_11_21_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "employees", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "role", null: false
    t.integer "hourly_rate_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["location_id"], name: "index_employees_on_location_id"
    t.check_constraint "hourly_rate_cents > 0", name: "employees_rate_positive"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "time_zone", default: "America/Vancouver", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shifts", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.bigint "employee_id"
    t.string "role", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_shifts_on_employee_id"
    t.index ["location_id", "starts_at"], name: "index_shifts_on_location_id_and_starts_at"
    t.index ["location_id"], name: "index_shifts_on_location_id"
    t.check_constraint "(ends_at - starts_at) <= 'PT16H'::interval", name: "shifts_at_most_16_hours"
    t.check_constraint "ends_at > starts_at", name: "shifts_end_after_start"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'cancelled'::character varying]::text[])", name: "shifts_status_known"
    t.exclusion_constraint "employee_id WITH =, tsrange(starts_at, ends_at) WITH &&", where: "(employee_id IS NOT NULL) AND ((status)::text = 'scheduled'::text)", using: :gist, name: "shifts_no_double_booking"
  end

  create_table "swap_requests", force: :cascade do |t|
    t.bigint "shift_id", null: false
    t.bigint "from_employee_id", null: false
    t.bigint "to_employee_id", null: false
    t.string "status", default: "pending", null: false
    t.string "decision_note"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_employee_id"], name: "index_swap_requests_on_from_employee_id"
    t.index ["shift_id"], name: "index_swap_requests_on_shift_id"
    t.index ["shift_id"], name: "one_pending_swap_per_shift", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["to_employee_id"], name: "index_swap_requests_on_to_employee_id"
    t.check_constraint "from_employee_id <> to_employee_id", name: "swap_requests_two_people"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])", name: "swap_requests_status_known"
  end

  add_foreign_key "employees", "locations"
  add_foreign_key "shifts", "employees"
  add_foreign_key "shifts", "locations"
  add_foreign_key "swap_requests", "employees", column: "from_employee_id"
  add_foreign_key "swap_requests", "employees", column: "to_employee_id"
  add_foreign_key "swap_requests", "shifts"
end
