class Location < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error
  has_many :shifts, dependent: :restrict_with_error

  validates :name, presence: true
  validate { errors.add(:time_zone, "is not a known time zone") unless ActiveSupport::TimeZone[time_zone.to_s] }

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  # BC's Employment Standards Act counts a week from Sunday to Saturday.
  def week_start_for(date)
    date = date.to_date
    date - date.wday
  end

  def week_range(week_start)
    from = zone.local(week_start.year, week_start.month, week_start.day)
    from...(from + 7.days)
  end
end
