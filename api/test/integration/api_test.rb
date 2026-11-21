require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @ana = employee("Ana Lee", rate: 2000)
    @ben = employee("Ben Ito", rate: 2200)
  end

  def json = JSON.parse(response.body)

  test "schedule lists the week from Sunday with its shifts" do
    shift(@ana, 1, 9, 17)
    shift(nil, 3, 11, 15, role: "cook")
    get "/api/locations/#{location.id}/schedule", params: { week: "2026-11-25" } # a Wednesday
    assert_response :ok
    assert_equal "2026-11-22", json["week_start"]
    assert_equal 7, json["days"].size
    assert_equal [@ana.id, nil], json["shifts"].map { |s| s["employee_id"] }
  end

  test "creating a shift returns overtime warnings" do
    (0..4).each { |d| shift(@ana, d, 9, 17) }
    post "/api/shifts", params: { shift: { location_id: location.id, employee_id: @ana.id, role: "cook",
                                           starts_at: at(6, 9).iso8601, ends_at: at(6, 13).iso8601 } }
    assert_response :created
    assert_match(/44\.0 h this week/, json["warnings"].first)
  end

  test "wall-clock times are read in the location's time zone, explicit offsets as given" do
    post "/api/shifts", params: { shift: { location_id: location.id, employee_id: @ana.id, role: "cook",
                                           starts_at: "2026-11-23T09:00", ends_at: "2026-11-23T17:00" } }
    assert_response :created
    assert_equal at(1, 9), Shift.find(json["shift"]["id"]).starts_at
    assert_equal ["2026-11-23T09:00", "2026-11-23T17:00"], json["shift"].values_at("starts_local", "ends_local")

    post "/api/shifts", params: { shift: { location_id: location.id, employee_id: @ben.id, role: "cook",
                                           starts_at: "2026-11-23T17:00:00Z", ends_at: "2026-11-24T01:00:00Z" } }
    assert_response :created
    assert_equal Time.utc(2026, 11, 23, 17), Shift.find(json["shift"]["id"]).starts_at
  end

  test "a missing or unreadable time is a 422, not a crash" do
    post "/api/shifts", params: { shift: { location_id: location.id, role: "cook", starts_at: "soon", ends_at: "" } }
    assert_response :unprocessable_content
    assert_includes json["errors"], "Starts at can't be blank"
  end

  test "a double booking is a 422 with a readable reason" do
    shift(@ana, 1, 9, 17)
    post "/api/shifts", params: { shift: { location_id: location.id, employee_id: @ana.id, role: "cook",
                                           starts_at: at(1, 15).iso8601, ends_at: at(1, 22).iso8601 } }
    assert_response :unprocessable_content
    assert_equal ["Employee already works Mon 23 Nov, 9:00 am – 5:00 pm"], json["errors"]
  end

  test "cancelling keeps the shift but takes it off the schedule and payroll" do
    s = shift(@ana, 1, 9, 17)
    delete "/api/shifts/#{s.id}"
    assert_response :ok
    get "/api/locations/#{location.id}/payroll", params: { week: "2026-11-22" }
    assert_equal 0, json["total_gross_cents"]
    assert Shift.exists?(s.id)
  end

  test "payroll applies BC overtime per employee" do
    (0..5).each { |d| shift(@ana, d, 9, 17) } # 48 h
    shift(@ben, 1, 9, 17)
    get "/api/locations/#{location.id}/payroll", params: { week: "2026-11-22" }
    ana = json["rows"].find { |r| r["employee"]["id"] == @ana.id }
    assert_equal [2400, 480], [ana["regular_minutes"], ana["overtime_minutes"]]
    assert_equal 80_000 + 24_000, ana["gross_cents"]
    assert_equal 104_000 + 17_600, json["total_gross_cents"]
  end

  test "swap request round trip" do
    s = shift(@ana, 2, 9, 17)
    post "/api/shifts/#{s.id}/swap_requests", params: { to_employee_id: @ben.id }
    assert_response :created
    swap_id = json["id"]

    post "/api/shifts/#{s.id}/swap_requests", params: { to_employee_id: @ben.id }
    assert_response :conflict

    post "/api/swap_requests/#{swap_id}/approve"
    assert_response :ok
    assert_equal @ben.id, s.reload.employee_id

    post "/api/swap_requests/#{swap_id}/approve"
    assert_response :conflict
  end

  test "unknown records are a 404 and bad weeks a 400" do
    get "/api/locations/999999/schedule"
    assert_response :not_found
    get "/api/locations/#{location.id}/schedule", params: { week: "next tuesday" }
    assert_response :bad_request
  end
end
