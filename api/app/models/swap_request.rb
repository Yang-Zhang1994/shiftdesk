class SwapRequest < ApplicationRecord
  belongs_to :shift
  belongs_to :from_employee, class_name: "Employee"
  belongs_to :to_employee, class_name: "Employee"

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: "pending", validate: true

  validate :sensible_swap, on: :create

  def as_json(*)
    { id:, status:, decision_note:, decided_at: decided_at&.iso8601,
      shift: shift.as_json, from_employee: from_employee.as_json, to_employee: to_employee.as_json }
  end

  private

  def sensible_swap
    return if shift.nil? || from_employee.nil? || to_employee.nil?

    errors.add(:shift, "is not assigned to #{from_employee.name}") if shift.employee_id != from_employee_id
    errors.add(:shift, "is cancelled") if shift.cancelled?
    errors.add(:to_employee, "must be someone else") if to_employee_id == from_employee_id
    errors.add(:to_employee, "works at a different location") if to_employee.location_id != shift.location_id
    errors.add(:to_employee, "is not a #{shift.role.humanize(capitalize: false)}") if to_employee.role != shift.role
  end
end
