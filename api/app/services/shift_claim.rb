# An employee picks up an open shift from the mobile app. The shift row is locked so two people
# tapping "Pick up" at once cannot both get it, and the exclusion constraint still refuses the
# claim if the employee was booked for an overlapping shift in the meantime.
class ShiftClaim
  Outcome = Data.define(:ok, :shift, :errors, :warnings)

  def initialize(shift_id, employee)
    @shift_id = shift_id
    @employee = employee
  end

  def call
    shift = nil
    warnings = []
    Shift.transaction do
      shift = Shift.lock.find(@shift_id)
      return failure(shift, "This shift was cancelled.") if shift.cancelled?
      return failure(shift, "#{shift.employee.name} already picked up this shift.") if shift.employee_id

      shift.employee = @employee
      return failure(shift.reload, *shift.errors.full_messages) unless shift.save

      warnings = ScheduleCheck.new(shift).warnings
    end
    Outcome.new(true, shift, [], warnings)
  rescue ActiveRecord::ExclusionViolation
    failure(Shift.find(@shift_id), "#{@employee.name} was just booked for an overlapping shift.")
  end

  private

  def failure(shift, *messages)
    Outcome.new(false, shift, messages, [])
  end
end
