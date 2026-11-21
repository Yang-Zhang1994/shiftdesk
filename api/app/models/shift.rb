class Shift < ApplicationRecord
  MAX_LENGTH = 16.hours

  belongs_to :location
  belongs_to :employee, optional: true # no employee = an open shift anyone with the role can take

  enum :status, { scheduled: "scheduled", cancelled: "cancelled" }, default: "scheduled", validate: true

  validates :role, inclusion: { in: Employee::ROLES }
  validates :starts_at, :ends_at, presence: true
  validate :ends_after_start
  validate :employee_fits
  validate :no_double_booking

  scope :live, -> { where(status: "scheduled") }
  scope :overlapping, ->(from, to) { where("starts_at < ? AND ends_at > ?", to, from) }

  def minutes
    ((ends_at - starts_at) / 60).round
  end

  # Clients get local wall-clock times as well as UTC instants, so they never need their own
  # time zone data (a browser's can be out of date; see README).
  def as_json(*)
    zone = location.zone
    { id:, location_id:, employee_id:, employee_name: employee&.name, role:, status:,
      starts_at: starts_at&.iso8601, ends_at: ends_at&.iso8601,
      starts_local: starts_at&.in_time_zone(zone)&.strftime("%Y-%m-%dT%H:%M"),
      ends_local: ends_at&.in_time_zone(zone)&.strftime("%Y-%m-%dT%H:%M"),
      minutes: (minutes if starts_at && ends_at) }
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?

    if ends_at <= starts_at
      errors.add(:ends_at, "must be after the start")
    elsif ends_at - starts_at > MAX_LENGTH
      errors.add(:ends_at, "makes the shift longer than 16 hours")
    end
  end

  def employee_fits
    return if employee.nil?

    errors.add(:employee, "works at a different location") if employee.location_id != location_id
    errors.add(:employee, "is a #{employee.role.humanize(capitalize: false)}, not a #{role.to_s.humanize(capitalize: false)}") if employee.role != role
  end

  # A friendly message for the common case. The database's exclusion constraint still catches
  # two saves racing each other, which this check alone cannot.
  def no_double_booking
    return if employee.nil? || cancelled? || starts_at.blank? || ends_at.blank?

    clash = Shift.live.where(employee_id:).where.not(id:).overlapping(starts_at, ends_at).first
    return unless clash

    local = clash.starts_at.in_time_zone(location.zone)
    errors.add(:employee, "already works #{local.strftime('%a %-d %b, %-l:%M %P')} – " \
                          "#{clash.ends_at.in_time_zone(location.zone).strftime('%-l:%M %P')}")
  end
end
