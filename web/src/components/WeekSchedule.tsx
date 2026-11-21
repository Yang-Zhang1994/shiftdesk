import { clock, dayLabel, hours, localDate } from '../time'
import type { Employee, Schedule, Shift } from '../types'

interface Props {
  schedule: Schedule
  onCancel: (shift: Shift) => void
}

export function WeekSchedule({ schedule, onCancel }: Props) {
  const cell = (who: Employee | null, day: string) =>
    schedule.shifts.filter(
      (s) => (who ? s.employee_id === who.id : s.employee_id === null) && localDate(s.starts_local) === day,
    )
  const weekMinutes = (who: Employee) =>
    schedule.shifts.filter((s) => s.employee_id === who.id).reduce((sum, s) => sum + s.minutes, 0)

  const row = (who: Employee | null) => (
    <tr key={who?.id ?? 'open'} className={who ? '' : 'open-row'}>
      <th scope="row">
        {who ? who.name : 'Open shifts'}
        {who && <span className="role">{who.role.replace('_', ' ')}</span>}
      </th>
      {schedule.days.map((day) => (
        <td key={day}>
          {cell(who, day).map((s) => (
            <div key={s.id} className={`shift role-${s.role}`}>
              <span>{clock(s.starts_local)}–{clock(s.ends_local)}</span>
              {!who && <span className="role">{s.role.replace('_', ' ')}</span>}
              <button type="button" className="link" onClick={() => onCancel(s)}
                aria-label={`Cancel ${who?.name ?? 'open'} shift ${dayLabel(day)} ${clock(s.starts_local)}`}>
                ×
              </button>
            </div>
          ))}
        </td>
      ))}
      <td className={who && weekMinutes(who) > 40 * 60 ? 'num over' : 'num'}>{who ? `${hours(weekMinutes(who))} h` : ''}</td>
    </tr>
  )

  return (
    <table className="schedule">
      <thead>
        <tr>
          <th scope="col">Employee</th>
          {schedule.days.map((d) => <th scope="col" key={d}>{dayLabel(d)}</th>)}
          <th scope="col" className="num">Week</th>
        </tr>
      </thead>
      <tbody>
        {schedule.employees.map(row)}
        {row(null)}
      </tbody>
    </table>
  )
}
