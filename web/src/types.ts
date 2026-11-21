export type Role = 'cook' | 'cashier' | 'shift_lead'

export interface Location { id: number; name: string; time_zone: string }

export interface Employee {
  id: number
  name: string
  email: string
  role: Role
  hourly_rate_cents: number
  location_id: number
}

export interface Shift {
  id: number
  location_id: number
  employee_id: number | null
  employee_name: string | null
  role: Role
  status: 'scheduled' | 'cancelled'
  starts_at: string
  ends_at: string
  /** Wall-clock time at the location, e.g. "2026-11-23T09:00" */
  starts_local: string
  ends_local: string
  minutes: number
}

export interface Schedule {
  location: Location
  week_start: string
  days: string[]
  employees: Employee[]
  shifts: Shift[]
}

export interface PayrollRow {
  employee: Employee
  regular_minutes: number
  overtime_minutes: number
  double_minutes: number
  total_minutes: number
  gross_cents: number
}

export interface Payroll { week_start: string; rows: PayrollRow[]; total_gross_cents: number }

export interface SwapRequest {
  id: number
  status: 'pending' | 'approved' | 'rejected'
  decision_note: string | null
  shift: Shift
  from_employee: Employee
  to_employee: Employee
}

export interface ShiftInput {
  location_id: number
  employee_id: number | null
  role: Role
  starts_at: string
  ends_at: string
}
