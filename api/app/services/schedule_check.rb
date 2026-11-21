# Warnings a manager should see before saving a shift. They do not block the save: sometimes
# overtime is the right call, but it should never be a surprise on payday.
class ScheduleCheck
  MIN_REST = 8.hours # BC ESA s. 36: 8 consecutive hours off between shifts

  def initialize(shift)
    @shift = shift
  end

  def warnings
    return [] if @shift.employee.nil? || @shift.cancelled? || @shift.starts_at.blank? || @shift.ends_at.blank?

    [overtime_warning, rest_warning].compact
  end

  private

  def location = @shift.location
  def employee = @shift.employee

  def week_shifts
    range = location.week_range(location.week_start_for(@shift.starts_at.in_time_zone(location.zone)))
    Shift.live.where(employee:).where(starts_at: range).where.not(id: @shift.id).to_a
  end

  def overtime_warning
    calc = PayrollCalculator.new(rate_cents: employee.hourly_rate_cents, zone: location.zone)
    before = calc.call(week_shifts)
    after = calc.call(week_shifts + [@shift])
    extra_ot = (after.overtime_minutes + after.double_minutes) - (before.overtime_minutes + before.double_minutes)
    return if extra_ot <= 0

    format("%s would work %.1f h this week, %.1f h of it at overtime rates. This shift costs $%.2f.",
           employee.name, after.total_minutes / 60.0,
           (after.overtime_minutes + after.double_minutes) / 60.0,
           (after.gross_cents - before.gross_cents) / 100.0)
  end

  def rest_warning
    neighbours = Shift.live.where(employee:).where.not(id: @shift.id)
                      .where(starts_at: (@shift.starts_at - 1.day)..(@shift.ends_at + 1.day))
    gaps = neighbours.filter_map do |other|
      if other.ends_at <= @shift.starts_at then @shift.starts_at - other.ends_at
      elsif other.starts_at >= @shift.ends_at then other.starts_at - @shift.ends_at
      end
    end
    short = gaps.select { |g| g < MIN_REST }.min
    return unless short

    format("%s would have only %.1f h off between shifts (BC requires 8).", employee.name, short / 3600.0)
  end
end
