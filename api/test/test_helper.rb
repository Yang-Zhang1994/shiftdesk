ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Sunday 22 November 2026 starts the week most tests use (BC weeks run Sunday to Saturday).
    WEEK = Date.new(2026, 11, 22)

    def location
      @location ||= Location.create!(name: "Kingsway Diner", time_zone: "America/Vancouver")
    end

    def employee(name = "Ana Lee", role: "cook", rate: 2000, at: location)
      Employee.create!(location: at, name:, email: "#{name.parameterize}@example.com", role:, hourly_rate_cents: rate)
    end

    # Local Vancouver time on the given day of WEEK (0 = Sunday).
    def at(day, hour, minute = 0)
      location.zone.local(WEEK.year, WEEK.month, WEEK.day + day, hour, minute)
    end

    def shift(who, day, from, to, role: who&.role || "cook", save: true)
      ends = to > from ? at(day, to) : at(day + 1, to) # "22 to 6" crosses midnight
      s = Shift.new(location:, employee: who, role:, starts_at: at(day, from), ends_at: ends)
      s.save! if save
      s
    end
  end
end
