require "test_helper"

class EmployeeAppTest < ActionDispatch::IntegrationTest
  setup do
    travel_to at(0, 8) # Sunday morning, before the week's shifts
    @ana = employee("Ana Lee", rate: 2000)
    @ben = employee("Ben Ito", rate: 2200)
  end

  def json = JSON.parse(response.body)

  test "week shows my shifts, my pay, and open shifts for my role" do
    shift(@ana, 1, 9, 17)
    shift(@ben, 2, 9, 17)
    open = shift(nil, 3, 11, 15)
    shift(nil, 3, 11, 15, role: "cashier")

    get "/api/employees/#{@ana.id}/week", params: { week: "2026-11-25" }
    assert_response :ok
    assert_equal "2026-11-22", json["week_start"]
    assert_equal ["2026-11-23T09:00"], json["shifts"].map { |s| s["starts_local"] }
    assert_equal [open.id], json["open_shifts"].map { |s| s["id"] }
    assert_equal({ "total_minutes" => 480, "overtime_minutes" => 0, "gross_cents" => 16_000 }, json["pay"])
  end

  test "open shifts that already started are not offered" do
    shift(nil, 0, 7, 11)
    get "/api/employees/#{@ana.id}/week", params: { week: "2026-11-22" }
    assert_empty json["open_shifts"]
  end

  test "claiming an open shift assigns it and returns warnings" do
    (1..5).each { |d| shift(@ana, d, 9, 17) }
    open = shift(nil, 6, 9, 13)
    post "/api/employees/#{@ana.id}/claims/#{open.id}"
    assert_response :ok
    assert_equal @ana.id, open.reload.employee_id
    assert_match(/44\.0 h this week/, json["warnings"].first)
  end

  test "a shift someone already picked up is a 409 naming them" do
    open = shift(nil, 3, 11, 15)
    post "/api/employees/#{@ben.id}/claims/#{open.id}"
    post "/api/employees/#{@ana.id}/claims/#{open.id}"
    assert_response :conflict
    assert_equal ["Ben Ito already picked up this shift."], json["errors"]
  end

  test "a claim that would double-book me is refused with the clash" do
    shift(@ana, 3, 9, 17)
    open = shift(nil, 3, 12, 20)
    post "/api/employees/#{@ana.id}/claims/#{open.id}"
    assert_response :conflict
    assert_equal ["Employee already works Wed 25 Nov, 9:00 am – 5:00 pm"], json["errors"]
    assert_nil open.reload.employee_id
  end

  test "a cashier cannot pick up a cook shift" do
    cy = employee("Cy Park", role: "cashier")
    open = shift(nil, 3, 11, 15, role: "cook")
    post "/api/employees/#{cy.id}/claims/#{open.id}"
    assert_response :conflict
    assert_equal ["Employee is a cashier, not a cook"], json["errors"]
  end
end
