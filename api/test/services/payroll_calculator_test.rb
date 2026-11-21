require "test_helper"

class PayrollCalculatorTest < ActiveSupport::TestCase
  setup { @ana = employee(rate: 2000) } # $20.00/h

  def pay(*shifts)
    PayrollCalculator.new(rate_cents: 2000, zone: location.zone).call(shifts)
  end

  test "eight hours is all regular time" do
    r = pay(shift(@ana, 1, 9, 17))
    assert_equal [480, 0, 0], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
    assert_equal 16_000, r.gross_cents
  end

  test "hours 8 to 12 are time and a half, past 12 double time" do
    r = pay(shift(@ana, 1, 6, 19)) # 13 hours
    assert_equal [480, 240, 60], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
    assert_equal 16_000 + 12_000 + 4_000, r.gross_cents
  end

  test "two shifts on one day add up before the daily limit" do
    r = pay(shift(@ana, 2, 6, 11), shift(@ana, 2, 15, 20)) # 5 h + 5 h
    assert_equal [480, 120, 0], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
  end

  test "regular hours past 40 in the week become time and a half" do
    r = pay(*(0..5).map { |d| shift(@ana, d, 9, 17) }) # six 8-hour days = 48 h
    assert_equal [2400, 480, 0], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
  end

  test "daily overtime is not counted again towards the weekly 40" do
    r = pay(*(0..4).map { |d| shift(@ana, d, 8, 18) }) # five 10-hour days: 40 regular + 10 daily OT
    assert_equal [2400, 600, 0], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
  end

  test "an overnight shift counts towards the day it starts" do
    r = pay(shift(@ana, 5, 22, 6), shift(@ana, 6, 9, 13)) # Fri 22:00-06:00 then Sat 09:00-13:00
    assert_equal [720, 0, 0], [r.regular_minutes, r.overtime_minutes, r.double_minutes]
  end

  test "pay rounds once, at the end, to the cent" do
    r = PayrollCalculator.new(rate_cents: 1785, zone: location.zone).call([shift(@ana, 1, 9, 18)]) # 9 h at $17.85
    assert_equal (1785 * 8 + 1785 * 1.5).round, r.gross_cents
  end
end
