module Api
  class LocationsController < ApplicationController
    def index
      render json: Location.order(:name).map { |l| { id: l.id, name: l.name, time_zone: l.time_zone } }
    end

    def employees
      render json: location.employees.order(:name)
    end

    def schedule
      range = location.week_range(week_start)
      shifts = location.shifts.live.where(starts_at: range).includes(:employee).order(:starts_at)
      render json: {
        location: { id: location.id, name: location.name, time_zone: location.time_zone },
        week_start: week_start.iso8601,
        days: (0..6).map { |i| (week_start + i).iso8601 },
        employees: location.employees.order(:role, :name),
        shifts:
      }
    end

    def payroll
      range = location.week_range(week_start)
      shifts = location.shifts.live.where(starts_at: range).where.not(employee_id: nil).group_by(&:employee_id)
      rows = location.employees.order(:name).map do |e|
        r = PayrollCalculator.new(rate_cents: e.hourly_rate_cents, zone: location.zone).call(shifts.fetch(e.id, []))
        { employee: e, regular_minutes: r.regular_minutes, overtime_minutes: r.overtime_minutes,
          double_minutes: r.double_minutes, total_minutes: r.total_minutes, gross_cents: r.gross_cents }
      end
      render json: { week_start: week_start.iso8601, rows:, total_gross_cents: rows.sum { |r| r[:gross_cents] } }
    end
  end
end
