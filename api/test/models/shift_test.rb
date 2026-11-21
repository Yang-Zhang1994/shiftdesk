require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  setup { @ana = employee }

  test "a shift must end after it starts and last at most 16 hours" do
    s = Shift.new(location:, employee: @ana, role: "cook", starts_at: at(1, 9), ends_at: at(1, 9))
    assert_not s.valid?
    assert_includes s.errors[:ends_at], "must be after the start"

    s.ends_at = at(2, 2) # 17 hours
    assert_not s.valid?
    assert_includes s.errors[:ends_at], "makes the shift longer than 16 hours"
  end

  test "an employee can only take shifts for their own role and location" do
    s = shift(@ana, 1, 9, 17, role: "cashier", save: false)
    assert_not s.valid?
    assert_includes s.errors[:employee], "is a cook, not a cashier"

    other = Location.create!(name: "Main St")
    s = Shift.new(location: other, employee: @ana, role: "cook", starts_at: at(1, 9), ends_at: at(1, 17))
    assert_not s.valid?
    assert_includes s.errors[:employee], "works at a different location"
  end

  test "overlapping shifts for one person are refused with the clashing times" do
    shift(@ana, 1, 9, 17)
    s = shift(@ana, 1, 16, 22, save: false)
    assert_not s.valid?
    assert_equal ["already works Mon 23 Nov, 9:00 am – 5:00 pm"], s.errors[:employee]
  end

  test "back-to-back shifts, open shifts and cancelled shifts do not clash" do
    first = shift(@ana, 1, 9, 17)
    assert shift(@ana, 1, 17, 21, save: false).valid?, "ends exactly when the next starts"
    assert shift(nil, 1, 9, 17, role: "cook", save: false).valid?, "open shift"

    first.update!(status: "cancelled")
    assert shift(@ana, 1, 10, 16, save: false).valid?, "cancelled shifts free the time"
  end

  test "the database refuses a double booking even when validations are skipped" do
    shift(@ana, 1, 9, 17)
    clash = shift(@ana, 1, 12, 20, save: false)
    assert_raises(ActiveRecord::ExclusionViolation) { clash.save!(validate: false) }
  end
end
