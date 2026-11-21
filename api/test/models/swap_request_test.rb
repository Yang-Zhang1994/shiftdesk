require "test_helper"

class SwapRequestTest < ActiveSupport::TestCase
  setup do
    @ana = employee("Ana Lee")
    @ben = employee("Ben Ito")
    @shift = shift(@ana, 1, 9, 17)
  end

  def swap(to = @ben) = SwapRequest.create!(shift: @shift, from_employee: @ana, to_employee: to)

  test "approving moves the shift to the colleague" do
    outcome = SwapApproval.new(swap).approve(note: "ok")
    assert outcome.ok
    assert_equal @ben, @shift.reload.employee
    assert_equal "approved", outcome.swap.status
  end

  test "a swap can only be decided once" do
    s = swap
    SwapApproval.new(s).reject(note: "short staffed")
    outcome = SwapApproval.new(s).approve
    assert_not outcome.ok
    assert_equal ["This swap was already rejected."], outcome.errors
    assert_equal @ana, @shift.reload.employee
  end

  test "approval fails cleanly if the colleague got booked in the meantime" do
    s = swap
    shift(@ben, 1, 12, 20)
    outcome = SwapApproval.new(s).approve
    assert_not outcome.ok
    assert_match(/already works Mon 23 Nov/, outcome.errors.first)
    assert_equal @ana, @shift.reload.employee
    assert s.reload.pending?
  end

  test "the colleague needs the same role and location" do
    cashier = employee("Cy Park", role: "cashier")
    s = SwapRequest.new(shift: @shift, from_employee: @ana, to_employee: cashier)
    assert_not s.valid?
    assert_includes s.errors[:to_employee], "is not a cook"
  end

  test "only one pending request per shift" do
    swap
    other = employee("Dee Roy")
    assert_raises(ActiveRecord::RecordNotUnique) { swap(other) }
  end
end
