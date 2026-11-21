require "test_helper"

# Two managers approve, at the same moment, two swaps that would hand Ben overlapping shifts.
# Each check passes on its own, so only the row lock and the exclusion constraint stop both.
# Runs outside a transaction so the two threads really race on separate connections.
class ConcurrentApprovalTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    [SwapRequest, Shift, Employee, Location].each(&:delete_all)
  end

  test "two racing approvals cannot double-book the same person" do
    ana, cy, ben = employee("Ana Lee"), employee("Cy Park"), employee("Ben Ito")
    swaps = [
      SwapRequest.create!(shift: shift(ana, 1, 9, 17), from_employee: ana, to_employee: ben),
      SwapRequest.create!(shift: shift(cy, 1, 12, 20), from_employee: cy, to_employee: ben)
    ]

    gate = Queue.new
    threads = swaps.map do |s|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          SwapApproval.new(SwapRequest.find(s.id)).approve
        end
      end
    end
    2.times { gate << :go }
    outcomes = threads.map(&:value)

    assert_equal 1, outcomes.count(&:ok), outcomes.map(&:errors).inspect
    assert_equal 1, Shift.live.where(employee: ben).count
  end
end
