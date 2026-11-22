# ShiftDesk

Scheduling and payroll preview for hourly teams, the kind of tool a restaurant manager uses every
week: build the schedule, approve shift swaps, and see what the week costs before payday. A Rails
API on PostgreSQL, a React + TypeScript web app for managers, and a React Native (Expo) app for
employees.

![Weekly schedule with an overtime warning](docs/schedule.png)

## What it does

- **Weekly schedule** per location (Sunday to Saturday, as BC counts weeks), with open shifts anyone
  in the role can take. Overnight shifts ("10 pm to 6 am") end the next morning.
- **Shift checks.** A shift is refused, with the reason, if the person is already working then, works
  a different role, or works at another location. A shift that is allowed but costly is saved with a
  warning: "Ana Lee would work 52.0 h this week, 12.0 h of it at overtime rates. This shift costs
  $129.00." It also warns when someone gets fewer than 8 hours off between shifts.
- **Payroll preview** under BC's Employment Standards Act: over 8 hours a day or 40 a week at 1.5×,
  over 12 hours a day at 2×. Hours already paid as daily overtime don't count towards the 40, so
  nothing is paid twice. Money is integer cents; pay rounds once, at the end.
- **Shift swaps.** An employee asks a colleague to cover; the manager approves or rejects. Approval
  re-checks everything, because the colleague may have been booked since the request was made.
- **Employee app (React Native).** Staff see their shifts for this week and next, their hours and
  estimated pay, and the open shifts in their role, and pick one up with a tap. The same checks
  apply: a clash is refused with the reason, and overtime or short rest comes back as a warning.

![Payroll preview](docs/payroll.png)

<p>
  <img src="docs/mobile-week.png" width="260" alt="Employee app: next week's shifts and open shifts">
  <img src="docs/mobile-pickup.png" width="260" alt="Picking up a shift returns the overtime and rest warnings">
</p>

## Design decisions

| Problem | What ShiftDesk does |
|---|---|
| Two managers book the same person at the same moment | Postgres refuses it: an **exclusion constraint** on `(employee_id, tsrange(starts_at, ends_at))` for live shifts. Model validations give a friendly message; the constraint is the guarantee. A test races two approvals on two database connections and only one wins, even with the model check switched off |
| Two approvals of the same swap at once | The swap and the shift are row-locked (`SELECT … FOR UPDATE`) in one transaction; a decided swap can't be decided again |
| Two employees tap "Pick up" on the same open shift | The claim locks the shift row, so the second sees it taken and gets "Ben Ito already picked up this shift." A test races two claims on separate connections |
| One request per shift | A partial unique index allows only one *pending* swap per shift |
| Bad data from any client | Check constraints: shifts end after they start and last at most 16 hours; known statuses; positive pay rates |
| Cancelling a shift | Marked cancelled, not deleted, so past schedules and payroll can still be explained |
| Time zones | The server owns them. The browser sends wall-clock times at the location ("2026-11-23T09:00") and shows the local times the server returns. See below for why |

### The time zone bug the demo found

While testing, Dev's 8 am shift showed as 7 am in the browser. The time zone database on the server
(macOS, tzdata 2026f) has Vancouver staying on UTC−7 after 1 November 2026, while the browser's
copy (Node/ICU, tzdata 2026a) still switched to UTC−8. The first version converted times in the
browser, so every shift was saved and shown an hour off. Now the browser does no time zone
arithmetic: the server interprets wall-clock times with its own, updatable data and sends back
`starts_local` / `ends_local` for display. A test posts "09:00" and checks it is stored as 9 am at
the location. The mobile app follows the same rule: it formats the server's wall-clock strings and
never converts times on the phone, whose time zone data can be just as stale.

## Run it

Requires Ruby 3.4+ (developed on 4.0), PostgreSQL 16 and Node 22+.

```bash
cd api
bundle install
bin/rails db:create db:migrate db:seed   # a demo diner with this week's schedule
bin/rails server                        # API on http://localhost:3000

cd ../web
npm install
npm run dev                              # http://localhost:5173 (proxies /api to Rails)

cd ../mobile
npm install
npx expo start --web                     # http://localhost:8081, or scan the QR code with Expo Go
```

On a phone, start Expo with `EXPO_PUBLIC_API_URL=http://<laptop LAN IP>:3000` and add that origin
to `CORS_ORIGINS` for Rails.

## API

| Method and path | Purpose |
|---|---|
| `GET /api/locations` | Locations |
| `GET /api/locations/:id/schedule?week=2026-11-25` | The week containing that date: days, employees, shifts |
| `GET /api/locations/:id/payroll?week=…` | Hours by rate and gross pay per employee |
| `POST /api/shifts` | Create a shift; returns `warnings`, or `422` with `errors` |
| `PATCH /api/shifts/:id`, `DELETE /api/shifts/:id` | Reassign or change times; cancel |
| `POST /api/shifts/:id/swap_requests` | Ask a colleague to cover (`to_employee_id`) |
| `GET /api/locations/:id/swap_requests?status=pending` | Swap requests |
| `POST /api/swap_requests/:id/approve`, `…/reject` | Decide; `409` with the reason if it can't go ahead |
| `GET /api/employees/:id/week?week=…` | Employee app: my shifts, my hours and estimated pay, open shifts in my role |
| `POST /api/employees/:id/claims/:shift_id` | Pick up an open shift; returns `warnings`, or `409` with the reason |

## Tests

```bash
cd api && bin/rails test        # 38 tests, 103 assertions, against a real Postgres database
cd web && npx vitest run        # 12 tests
cd mobile && npx jest           # 9 tests
```

| Suite | What it checks |
|---|---|
| `PayrollCalculatorTest` | 8 h regular; 13 h = 8 + 4 at 1.5× + 1 at 2×; two shifts in one day; 48 h week = 40 + 8; five 10 h days = 40 + 10 (daily overtime not counted twice); overnight shifts count to the start day; rounding to the cent |
| `ShiftTest` | Length limits; role and location must match; overlaps refused with the clashing times; back-to-back, open and cancelled shifts don't clash; **the database refuses a double booking even with validations skipped** |
| `ScheduleCheckTest` | Overtime warning with the cost; under-8-hours rest warning; open shifts |
| `SwapRequestTest` | Approval moves the shift; decided once only; fails cleanly if the colleague was booked meanwhile; same role and location; one pending request per shift |
| `ConcurrentApprovalTest` | Two threads approve conflicting swaps at once on separate connections; exactly one wins |
| `ConcurrentClaimTest` | Two employees claim the same open shift at once on separate connections; exactly one gets it |
| `EmployeeAppTest` | My week, pay and open shifts for my role; started shifts not offered; claims assign and warn; taken, clashing and wrong-role claims are refused with the reason |
| `ApiTest` | Week from Sunday, warnings on create, readable 422s, wall-clock times in the location zone, cancel keeps history, payroll totals, swap round trip, 404 and 400 |
| `time.test.ts` | Wall-clock times, overnight shifts across month and year ends, display formatting |
| `components.test.tsx` | The shift form sends the right payload and shows refusals and warnings; swap approvals pass warnings up and show conflicts; payroll highlights overtime |
| `format.test.ts` (mobile) | Dates and times read from the server's wall-clock strings, not the phone's time zone; next week across a month end |
| `MyWeek.test.tsx` (mobile) | Shows shifts, pay and open shifts; picking up shows the warning and refreshes; losing a race explains who got the shift; next week asks for the following Sunday |

GitHub Actions runs all three suites, the web linter and production build, and the mobile
typecheck on every push, with Postgres 16 as a service.

## Not covered

Authentication and roles (any user can act as the manager, and in the mobile app you pick who you
are), BC's other rules (minimum daily pay,
split shifts, statutory holidays), and multiple locations in the UI. Weeks run Sunday to Saturday
and a shift counts towards the day it starts, simplifications of how BC defines a day.
