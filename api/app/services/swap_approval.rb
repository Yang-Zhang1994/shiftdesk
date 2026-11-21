# Approving a swap moves the shift to the colleague who agreed to take it. The shift row is locked
# so two managers approving at once cannot both move it, and the database's exclusion constraint
# refuses the move if the colleague has since been booked for an overlapping shift.
class SwapApproval
  Outcome = Data.define(:ok, :swap, :errors, :warnings)

  def initialize(swap)
    @swap = swap
  end

  def approve(note: nil)
    warnings = []
    SwapRequest.transaction do
      @swap.lock!
      shift = Shift.lock.find(@swap.shift_id)
      return failure("This swap was already #{@swap.status}.") unless @swap.pending?
      return failure("The shift is no longer #{@swap.from_employee.name}'s.") if shift.employee_id != @swap.from_employee_id

      shift.employee = @swap.to_employee
      unless shift.save
        return failure(*shift.errors.full_messages)
      end
      warnings = ScheduleCheck.new(shift).warnings
      @swap.update!(status: "approved", decision_note: note, decided_at: Time.current)
    end
    Outcome.new(true, @swap, [], warnings)
  rescue ActiveRecord::ExclusionViolation
    failure("#{@swap.to_employee.name} was just booked for an overlapping shift.")
  end

  def reject(note: nil)
    SwapRequest.transaction do
      @swap.lock!
      return failure("This swap was already #{@swap.status}.") unless @swap.pending?

      @swap.update!(status: "rejected", decision_note: note, decided_at: Time.current)
    end
    Outcome.new(true, @swap, [], [])
  end

  private

  def failure(*messages)
    Outcome.new(false, @swap.reload, messages, [])
  end
end
