# A week at a fictional diner, built around the current week so the demo is never empty.
# Run: bin/rails db:seed (safe to rerun; it starts from a clean slate).
[SwapRequest, Shift, Employee, Location].each(&:delete_all)

diner = Location.create!(name: "Kingsway Diner (demo)", time_zone: "America/Vancouver")
zone = diner.zone
sunday = diner.week_start_for(Time.current.in_time_zone(zone).to_date)

staff = {
  "Ana Lee" => ["cook", 2150], "Ben Ito" => ["cook", 2050], "Carla Diaz" => ["cook", 2300],
  "Dev Patel" => ["cashier", 1900], "Emma Roy" => ["cashier", 1925], "Farah Khan" => ["cashier", 1950],
  "Gus Novak" => ["shift_lead", 2600]
}.to_h do |name, (role, rate)|
  [name, Employee.create!(location: diner, name:, email: "#{name.parameterize}@kingsway.example", role:, hourly_rate_cents: rate)]
end

def add(diner, zone, sunday, who, role, day, from, to)
  start = zone.local(sunday.year, sunday.month, sunday.day, from) + day.days
  finish = to > from ? start.change(hour: to) : (start + 1.day).change(hour: to)
  Shift.create!(location: diner, employee: who, role:, starts_at: start, ends_at: finish)
end

# Cooks: Ana is heading for overtime (six 8-hour days), Carla closes late.
(0..5).each { |d| add(diner, zone, sunday, staff["Ana Lee"], "cook", d, 7, 15) }
[1, 2, 4, 5].each { |d| add(diner, zone, sunday, staff["Ben Ito"], "cook", d, 11, 19) }
[2, 3, 4, 6].each { |d| add(diner, zone, sunday, staff["Carla Diaz"], "cook", d, 15, 23) }
# Cashiers.
[0, 1, 2, 3].each { |d| add(diner, zone, sunday, staff["Dev Patel"], "cashier", d, 8, 16) }
[3, 4, 5, 6].each { |d| add(diner, zone, sunday, staff["Emma Roy"], "cashier", d, 8, 16) }
[0, 2, 4, 5].each { |d| add(diner, zone, sunday, staff["Farah Khan"], "cashier", d, 14, 22) }
# Shift lead, including one long Saturday.
[1, 2, 3, 4].each { |d| add(diner, zone, sunday, staff["Gus Novak"], "shift_lead", d, 10, 18) }
add(diner, zone, sunday, staff["Gus Novak"], "shift_lead", 6, 8, 18)
# Open shifts nobody has taken yet.
add(diner, zone, sunday, nil, "cook", 6, 7, 15)
add(diner, zone, sunday, nil, "cashier", 1, 16, 22)
# Next week, for the employee app: Ana's first shifts and open shifts she can pick up.
(8..10).each { |d| add(diner, zone, sunday, staff["Ana Lee"], "cook", d, 7, 15) }
add(diner, zone, sunday, nil, "cook", 8, 16, 22)
add(diner, zone, sunday, nil, "cook", 12, 9, 17)
add(diner, zone, sunday, nil, "cook", 13, 7, 15)
add(diner, zone, sunday, nil, "cashier", 9, 8, 16)

# Dev asked Emma to cover his Wednesday.
wednesday = Shift.find_by!(employee: staff["Dev Patel"], starts_at: zone.local(sunday.year, sunday.month, sunday.day, 8) + 3.days)
SwapRequest.create!(shift: wednesday, from_employee: staff["Dev Patel"], to_employee: staff["Farah Khan"])

puts "Seeded #{Employee.count} employees and #{Shift.count} shifts for the week of #{sunday}."
