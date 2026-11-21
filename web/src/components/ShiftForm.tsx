import { useState } from 'react'
import { api, ApiError } from '../api'
import { dayLabel, shiftTimes } from '../time'
import type { Employee, Role } from '../types'

interface Props {
  locationId: number
  days: string[]
  employees: Employee[]
  onSaved: () => void
}

const ROLES: Role[] = ['cook', 'cashier', 'shift_lead']

export function ShiftForm({ locationId, days, employees, onSaved }: Props) {
  const [employeeId, setEmployeeId] = useState('')
  const [role, setRole] = useState<Role>('cook')
  const [day, setDay] = useState(days[1] ?? days[0])
  const [from, setFrom] = useState('09:00')
  const [to, setTo] = useState('17:00')
  const [errors, setErrors] = useState<string[]>([])
  const [warnings, setWarnings] = useState<string[]>([])
  const [saving, setSaving] = useState(false)

  const pickEmployee = (id: string) => {
    setEmployeeId(id)
    const e = employees.find((x) => String(x.id) === id)
    if (e) setRole(e.role) // an employee can only work their own role
  }

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    setSaving(true)
    setErrors([])
    setWarnings([])
    try {
      const res = await api.createShift({
        location_id: locationId,
        employee_id: employeeId ? Number(employeeId) : null,
        role,
        ...shiftTimes(day, from, to),
      })
      setWarnings(res.warnings)
      onSaved()
    } catch (e) {
      setErrors(e instanceof ApiError ? e.messages : ['Could not reach the server.'])
    } finally {
      setSaving(false)
    }
  }

  return (
    <form className="shift-form" onSubmit={submit} aria-label="Add a shift">
      <label>
        Employee
        <select value={employeeId} onChange={(e) => pickEmployee(e.target.value)}>
          <option value="">Open shift (anyone can take it)</option>
          {employees.map((e) => (
            <option key={e.id} value={e.id}>
              {e.name} ({e.role.replace('_', ' ')})
            </option>
          ))}
        </select>
      </label>
      <label>
        Role
        <select value={role} onChange={(e) => setRole(e.target.value as Role)} disabled={employeeId !== ''}>
          {ROLES.map((r) => (
            <option key={r} value={r}>{r.replace('_', ' ')}</option>
          ))}
        </select>
      </label>
      <label>
        Day
        <select value={day} onChange={(e) => setDay(e.target.value)}>
          {days.map((d) => (
            <option key={d} value={d}>{dayLabel(d)}</option>
          ))}
        </select>
      </label>
      <label>
        From
        <input type="time" value={from} onChange={(e) => setFrom(e.target.value)} required />
      </label>
      <label>
        To
        <input type="time" value={to} onChange={(e) => setTo(e.target.value)} required />
      </label>
      <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Add shift'}</button>

      {errors.length > 0 && (
        <ul className="messages error" role="alert">
          {errors.map((m) => <li key={m}>{m}</li>)}
        </ul>
      )}
      {warnings.length > 0 && (
        <ul className="messages warning" role="status">
          {warnings.map((m) => <li key={m}>Saved, but: {m}</li>)}
        </ul>
      )}
    </form>
  )
}
