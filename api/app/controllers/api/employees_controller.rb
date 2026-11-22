module Api
  # What the employee app shows: my shifts this week, my estimated pay, and open shifts I can take.
  class EmployeesController < ApplicationController
    def week
      range = location.week_range(week_start)
      mine = Shift.live.where(employee:, starts_at: range).includes(:location).order(:starts_at).to_a
      open = location.shifts.live.where(employee_id: nil, role: employee.role, starts_at: range)
                     .where("starts_at > ?", Time.current).order(:starts_at)
      pay = PayrollCalculator.new(rate_cents: employee.hourly_rate_cents, zone: location.zone).call(mine)
      render json: {
        employee:, location: { id: location.id, name: location.name, time_zone: location.time_zone },
        week_start: week_start.iso8601, shifts: mine, open_shifts: open,
        pay: { total_minutes: pay.total_minutes, overtime_minutes: pay.overtime_minutes + pay.double_minutes,
               gross_cents: pay.gross_cents }
      }
    end

    def claim
      outcome = ShiftClaim.new(params[:shift_id], employee).call
      if outcome.ok
        render json: { shift: outcome.shift, warnings: outcome.warnings }
      else
        render json: { shift: outcome.shift, errors: outcome.errors }, status: :conflict
      end
    end

    private

    def employee
      @employee ||= Employee.find(params[:employee_id])
    end

    def location
      @location ||= employee.location
    end
  end
end
