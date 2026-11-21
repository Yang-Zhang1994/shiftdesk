require "test_helper"

class ScheduleCheckTest < ActiveSupport::TestCase
  setup { @ana = employee(rate: 2000) }

  test "no warnings for an ordinary shift" do
    assert_empty ScheduleCheck.new(shift(@ana, 1, 9, 17)).warnings
  end

  test "warns when a shift pushes someone into weekly overtime, with the cost" do
    (0..4).each { |d| shift(@ana, d, 9, 17) } # 40 h already
    sat = shift(@ana, 6, 9, 13, save: false)
    assert_equal ["Ana Lee would work 44.0 h this week, 4.0 h of it at overtime rates. This shift costs $120.00."],
                 ScheduleCheck.new(sat).warnings
  end

  test "warns about fewer than 8 hours off between shifts" do
    shift(@ana, 1, 14, 23) # closes Monday 11 pm
    opening = shift(@ana, 2, 5, 11, save: false)
    assert_includes ScheduleCheck.new(opening).warnings, "Ana Lee would have only 6.0 h off between shifts (BC requires 8)."
  end

  test "open shifts have nobody to warn about" do
    assert_empty ScheduleCheck.new(shift(nil, 1, 9, 23, role: "cook", save: false)).warnings
  end
end
