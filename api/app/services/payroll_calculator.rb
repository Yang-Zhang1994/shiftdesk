# Weekly pay for one employee under BC's Employment Standards Act (s. 40):
#   - a day: the first 8 hours are regular, hours 8-12 are paid 1.5x, hours over 12 are paid 2x;
#   - a week (Sunday to Saturday): regular hours over 40 are paid 1.5x. Hours already paid
#     as daily overtime do not count towards the 40, so nothing is paid twice.
# A shift counts towards the day it starts on, in the location's time zone. Amounts are in cents
# and minutes so there is no floating-point money.
class PayrollCalculator
  DAILY_REGULAR = 8 * 60
  DAILY_TIME_AND_A_HALF = 12 * 60
  WEEKLY_REGULAR = 40 * 60

  Result = Data.define(:regular_minutes, :overtime_minutes, :double_minutes, :gross_cents) do
    def total_minutes = regular_minutes + overtime_minutes + double_minutes
  end

  def initialize(rate_cents:, zone:)
    @rate_cents = rate_cents
    @zone = zone
  end

  def call(shifts)
    minutes_by_day = Hash.new(0)
    shifts.each { |s| minutes_by_day[s.starts_at.in_time_zone(@zone).to_date] += s.minutes }

    regular = overtime = double = 0
    minutes_by_day.sort.each do |_day, worked|
      day_regular = [worked, DAILY_REGULAR].min
      overtime += ([worked, DAILY_TIME_AND_A_HALF].min - day_regular)
      double += [worked - DAILY_TIME_AND_A_HALF, 0].max

      # Weekly rule: regular minutes past 40 hours move to time and a half.
      over_week = [regular + day_regular - WEEKLY_REGULAR, 0].max
      regular += day_regular - over_week
      overtime += over_week
    end

    Result.new(regular, overtime, double, gross(regular, overtime, double))
  end

  private

  def gross(regular, overtime, double)
    cents = Rational(@rate_cents * regular, 60) +
            Rational(@rate_cents * overtime * 3, 120) +
            Rational(@rate_cents * double * 2, 60)
    cents.round
  end
end
