import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { PayrollTable } from './PayrollTable'
import { ShiftForm } from './ShiftForm'
import { SwapRequests } from './SwapRequests'
import type { Employee, SwapRequest } from '../types'

const ana: Employee = { id: 1, name: 'Ana Lee', email: 'a@x.ca', role: 'cook', hourly_rate_cents: 2000, location_id: 7 }
const ben: Employee = { id: 2, name: 'Ben Ito', email: 'b@x.ca', role: 'cook', hourly_rate_cents: 2200, location_id: 7 }
const dev: Employee = { id: 3, name: 'Dev Patel', email: 'd@x.ca', role: 'cashier', hourly_rate_cents: 1900, location_id: 7 }
const days = ['2026-11-22', '2026-11-23', '2026-11-24', '2026-11-25', '2026-11-26', '2026-11-27', '2026-11-28']

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn().mockResolvedValue({ ok: status < 400, status, json: async () => body })
  vi.stubGlobal('fetch', fn)
  return fn
}

afterEach(() => vi.unstubAllGlobals())

describe('ShiftForm', () => {
  const renderForm = (onSaved = vi.fn()) =>
    render(<ShiftForm locationId={7} days={days} employees={[ana, dev]} onSaved={onSaved} />)

  it("sends wall-clock times at the location and takes the employee's role", async () => {
    const fetch = mockFetch(201, { shift: {}, warnings: [] })
    const onSaved = vi.fn()
    renderForm(onSaved)
    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'Dev Patel (cashier)')
    expect(screen.getByLabelText('Role')).toHaveValue('cashier')
    await userEvent.selectOptions(screen.getByLabelText('Day'), 'Fri, Nov 27')
    await userEvent.clear(screen.getByLabelText('From'))
    await userEvent.type(screen.getByLabelText('From'), '22:00')
    await userEvent.clear(screen.getByLabelText('To'))
    await userEvent.type(screen.getByLabelText('To'), '06:00')
    await userEvent.click(screen.getByRole('button', { name: 'Add shift' }))

    await waitFor(() => expect(onSaved).toHaveBeenCalled())
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe('/api/shifts')
    expect(JSON.parse(init.body)).toEqual({
      shift: { location_id: 7, employee_id: 3, role: 'cashier', starts_at: '2026-11-27T22:00', ends_at: '2026-11-28T06:00' },
    })
  })

  it("shows the server's reason when a shift is refused", async () => {
    mockFetch(422, { errors: ['Employee already works Mon 23 Nov, 9:00 am – 5:00 pm'] })
    renderForm()
    await userEvent.selectOptions(screen.getByLabelText('Employee'), 'Ana Lee (cook)')
    await userEvent.click(screen.getByRole('button', { name: 'Add shift' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('already works Mon 23 Nov')
  })

  it('keeps overtime warnings visible after saving', async () => {
    mockFetch(201, { shift: {}, warnings: ['Ana Lee would work 44.0 h this week, 4.0 h of it at overtime rates.'] })
    renderForm()
    await userEvent.click(screen.getByRole('button', { name: 'Add shift' }))
    expect(await screen.findByRole('status')).toHaveTextContent('Saved, but: Ana Lee would work 44.0 h')
  })
})

describe('SwapRequests', () => {
  const swap: SwapRequest = {
    id: 9, status: 'pending', decision_note: null, from_employee: ana, to_employee: ben,
    shift: { id: 4, location_id: 7, employee_id: 1, employee_name: 'Ana Lee', role: 'cook', status: 'scheduled',
      starts_at: '2026-11-25T16:00:00Z', ends_at: '2026-11-26T00:00:00Z',
      starts_local: '2026-11-25T08:00', ends_local: '2026-11-25T16:00', minutes: 480 },
  }

  it("describes the swap in the location's local time and passes approval warnings up", async () => {
    mockFetch(200, { swap: { ...swap, status: 'approved' }, warnings: ['Ben Ito would have only 6.0 h off between shifts (BC requires 8).'] })
    const onDecided = vi.fn()
    render(<SwapRequests swaps={[swap]} onDecided={onDecided} />)
    expect(screen.getByText(/to cover/)).toHaveTextContent('Wed, Nov 25, 8:00a–4:00p (cook)')
    await userEvent.click(screen.getByRole('button', { name: 'Approve' }))
    await waitFor(() => expect(onDecided).toHaveBeenCalledWith(['Ben Ito would have only 6.0 h off between shifts (BC requires 8).']))
  })

  it('shows why an approval was refused and keeps the request', async () => {
    mockFetch(409, { errors: ['Ben Ito was just booked for an overlapping shift.'] })
    const onDecided = vi.fn()
    render(<SwapRequests swaps={[swap]} onDecided={onDecided} />)
    await userEvent.click(screen.getByRole('button', { name: 'Approve' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('just booked for an overlapping shift')
    expect(onDecided).not.toHaveBeenCalled()
  })
})

describe('PayrollTable', () => {
  it('shows hours by rate and highlights overtime', () => {
    render(<PayrollTable payroll={{
      week_start: '2026-11-22', total_gross_cents: 104000,
      rows: [{ employee: ana, regular_minutes: 2400, overtime_minutes: 480, double_minutes: 0, total_minutes: 2880, gross_cents: 104000 }],
    }} />)
    const row = screen.getByRole('row', { name: /Ana Lee/ })
    expect(row).toHaveTextContent('$20.00/h40 h8 h0 h$1,040.00')
    expect(screen.getByText('8 h')).toHaveClass('over')
    expect(screen.getByRole('row', { name: /Total wages/ })).toHaveTextContent('$1,040.00')
  })
})
