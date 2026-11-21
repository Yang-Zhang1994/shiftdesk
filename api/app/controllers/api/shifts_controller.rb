module Api
  class ShiftsController < ApplicationController
    def create
      shift = Shift.new(shift_params.slice(:location_id, :employee_id, :role))
      assign_times(shift)
      save(shift, :created)
    end

    def update
      shift = Shift.find(params[:id])
      shift.assign_attributes(shift_params.slice(:employee_id, :role))
      assign_times(shift)
      save(shift, :ok)
    end

    # Shifts are cancelled, not deleted, so the week's history and payroll stay explainable.
    def destroy
      shift = Shift.find(params[:id])
      shift.update!(status: "cancelled")
      render json: { shift: }
    end

    private

    def save(shift, status)
      if shift.save
        render json: { shift:, warnings: ScheduleCheck.new(shift).warnings }, status:
      else
        render_errors(shift)
      end
    rescue ActiveRecord::ExclusionViolation
      render_errors("Employee was just booked for an overlapping shift by someone else.", status: :conflict)
    end

    # "2026-11-23T09:00" means 9 am at the shift's location, worked out with the server's time zone
    # data. A time with an explicit offset ("...T09:00:00-08:00") is taken as that exact instant.
    def assign_times(shift)
      zone = shift.location&.zone || Time.zone
      %i[starts_at ends_at].each do |attr|
        value = shift_params[attr]
        next if value.nil?

        shift[attr] = value.present? ? zone.parse(value) : nil
      rescue ArgumentError
        shift[attr] = nil
      end
    end

    def shift_params
      params.require(:shift).permit(:location_id, :employee_id, :role, :starts_at, :ends_at)
    end
  end
end
