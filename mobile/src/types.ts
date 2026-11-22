export type Role = 'cook' | 'cashier' | 'shift_lead'

export interface Location { id: number; name: string; time_zone: string }

export interface Employee { id: number; name: string; role: Role; location_id: number }

export interface Shift {
  id: number
  employee_id: number | null
  role: Role
  /** Wall-clock time at the location, e.g. "2026-11-23T09:00". The app never does time zone math. */
  starts_local: string
  ends_local: string
  minutes: number
}

export interface Week {
  employee: Employee
  location: Location
  week_start: string
  shifts: Shift[]
  open_shifts: Shift[]
  pay: { total_minutes: number; overtime_minutes: number; gross_cents: number }
}
