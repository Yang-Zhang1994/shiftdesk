import { hours, money } from '../time'
import type { Payroll } from '../types'

export function PayrollTable({ payroll }: { payroll: Payroll }) {
  return (
    <table className="payroll">
      <caption>
        BC overtime: over 8 h a day or 40 h a week at 1.5×, over 12 h a day at 2×. Hours already paid as daily overtime
        don't count towards the 40.
      </caption>
      <thead>
        <tr>
          <th scope="col">Employee</th>
          <th scope="col" className="num">Rate</th>
          <th scope="col" className="num">Regular</th>
          <th scope="col" className="num">1.5×</th>
          <th scope="col" className="num">2×</th>
          <th scope="col" className="num">Gross</th>
        </tr>
      </thead>
      <tbody>
        {payroll.rows.map((r) => (
          <tr key={r.employee.id}>
            <th scope="row">{r.employee.name}</th>
            <td className="num">{money(r.employee.hourly_rate_cents)}/h</td>
            <td className="num">{hours(r.regular_minutes)} h</td>
            <td className={r.overtime_minutes ? 'num over' : 'num'}>{hours(r.overtime_minutes)} h</td>
            <td className={r.double_minutes ? 'num over' : 'num'}>{hours(r.double_minutes)} h</td>
            <td className="num">{money(r.gross_cents)}</td>
          </tr>
        ))}
      </tbody>
      <tfoot>
        <tr>
          <th scope="row" colSpan={5}>Total wages this week</th>
          <td className="num">{money(payroll.total_gross_cents)}</td>
        </tr>
      </tfoot>
    </table>
  )
}
