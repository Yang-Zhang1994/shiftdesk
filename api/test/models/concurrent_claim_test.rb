require "test_helper"

# Two employees tap "Pick up" on the same open shift at the same moment. Each sees it unassigned
# before the save, so only the row lock stops both from getting it.
class ConcurrentClaimTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    [SwapRequest, Shift, Employee, Location].each(&:delete_all)
  end

  test "two racing claims give the shift to exactly one person" do
    people = [employee("Ana Lee"), employee("Ben Ito")]
    open = shift(nil, 3, 11, 15)

    gate = Queue.new
    threads = people.map do |person|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          ShiftClaim.new(open.id, Employee.find(person.id)).call
        end
      end
    end
    2.times { gate << :go }
    outcomes = threads.map(&:value)

    assert_equal 1, outcomes.count(&:ok), outcomes.map(&:errors).inspect
    winner = outcomes.find(&:ok).shift.employee_id
    assert_equal winner, open.reload.employee_id
    assert_match(/already picked up this shift/, outcomes.reject(&:ok).first.errors.first)
  end
end
