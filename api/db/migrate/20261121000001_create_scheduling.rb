class CreateScheduling < ActiveRecord::Migration[8.1]
  def change
    # btree_gist lets one exclusion constraint compare employee ids (=) and time ranges (&&).
    enable_extension "btree_gist"

    create_table :locations do |t|
      t.string :name, null: false
      t.string :time_zone, null: false, default: "America/Vancouver"
      t.timestamps
    end

    create_table :employees do |t|
      t.references :location, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, null: false
      t.integer :hourly_rate_cents, null: false
      t.timestamps
    end
    add_index :employees, :email, unique: true
    add_check_constraint :employees, "hourly_rate_cents > 0", name: "employees_rate_positive"

    create_table :shifts do |t|
      t.references :location, null: false, foreign_key: true
      t.references :employee, foreign_key: true # null = open shift nobody has taken yet
      t.string :role, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "scheduled"
      t.timestamps
    end
    add_index :shifts, [:location_id, :starts_at]
    add_check_constraint :shifts, "ends_at > starts_at", name: "shifts_end_after_start"
    add_check_constraint :shifts, "ends_at - starts_at <= interval '16 hours'", name: "shifts_at_most_16_hours"
    add_check_constraint :shifts, "status IN ('scheduled', 'cancelled')", name: "shifts_status_known"

    # The last line of defence against double-booking: even if two managers save at the same
    # moment, Postgres refuses a second live shift that overlaps the same employee's time.
    add_exclusion_constraint :shifts, "employee_id WITH =, tsrange(starts_at, ends_at) WITH &&",
      using: :gist, where: "employee_id IS NOT NULL AND status = 'scheduled'", name: "shifts_no_double_booking"

    create_table :swap_requests do |t|
      t.references :shift, null: false, foreign_key: true
      t.references :from_employee, null: false, foreign_key: { to_table: :employees }
      t.references :to_employee, null: false, foreign_key: { to_table: :employees }
      t.string :status, null: false, default: "pending"
      t.string :decision_note
      t.datetime :decided_at
      t.timestamps
    end
    add_check_constraint :swap_requests, "status IN ('pending', 'approved', 'rejected')", name: "swap_requests_status_known"
    add_check_constraint :swap_requests, "from_employee_id <> to_employee_id", name: "swap_requests_two_people"
    # At most one open request per shift.
    add_index :swap_requests, :shift_id, unique: true, where: "status = 'pending'", name: "one_pending_swap_per_shift"
  end
end
