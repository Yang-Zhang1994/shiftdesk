import { fireEvent, render, screen, waitFor } from '@testing-library/react-native'
import { api, ApiError } from '../api'
import { MyWeek } from '../screens/MyWeek'
import type { Employee, Week } from '../types'

jest.mock('../api', () => {
  const actual = jest.requireActual('../api')
  return { ...actual, api: { week: jest.fn(), claim: jest.fn() } }
})
const mocked = api as jest.Mocked<typeof api>

const ana: Employee = { id: 1, name: 'Ana Lee', role: 'cook', location_id: 1 }
const open = { id: 9, employee_id: null, role: 'cook' as const, starts_local: '2026-11-28T09:00', ends_local: '2026-11-28T13:00', minutes: 240 }
const week = (over: Partial<Week> = {}): Week => ({
  employee: ana,
  location: { id: 1, name: 'Kingsway Diner', time_zone: 'America/Vancouver' },
  week_start: '2026-11-22',
  shifts: [{ id: 3, employee_id: 1, role: 'cook', starts_local: '2026-11-23T09:00', ends_local: '2026-11-23T17:00', minutes: 480 }],
  open_shifts: [open],
  pay: { total_minutes: 480, overtime_minutes: 0, gross_cents: 16000 },
  ...over,
})

beforeEach(() => jest.resetAllMocks())

test('shows my shifts, estimated pay and open shifts', async () => {
  mocked.week.mockResolvedValue(week())
  await render(<MyWeek employee={ana} onSwitch={() => {}} />)
  expect(await screen.findByText('8.0 h')).toBeTruthy()
  expect(screen.getByText(/about \$160\.00/)).toBeTruthy()
  expect(screen.getByText('Mon 23 Nov')).toBeTruthy()
  expect(screen.getByText('9:00a–5:00p')).toBeTruthy()
  expect(screen.getByLabelText('Pick up Sat 28 Nov 9:00a')).toBeTruthy()
})

test('picking up a shift shows the overtime warning and refreshes', async () => {
  mocked.week.mockResolvedValueOnce(week()).mockResolvedValueOnce(week({ open_shifts: [] }))
  mocked.claim.mockResolvedValue({ shift: { ...open, employee_id: 1 }, warnings: ['Ana Lee would work 44.0 h this week, 4.0 h of it at overtime rates.'] })
  await render(<MyWeek employee={ana} onSwitch={() => {}} />)
  await fireEvent.press(await screen.findByLabelText('Pick up Sat 28 Nov 9:00a'))

  expect(await screen.findByText(/Picked up\. Ana Lee would work 44\.0 h/)).toBeTruthy()
  expect(mocked.claim).toHaveBeenCalledWith(1, 9)
  await waitFor(() => expect(screen.getByText('Nothing open for your role right now.')).toBeTruthy())
})

test('losing the race to a colleague explains who got it', async () => {
  mocked.week.mockResolvedValue(week())
  mocked.claim.mockRejectedValue(new ApiError(409, ['Ben Ito already picked up this shift.']))
  await render(<MyWeek employee={ana} onSwitch={() => {}} />)
  await fireEvent.press(await screen.findByLabelText('Pick up Sat 28 Nov 9:00a'))
  expect(await screen.findByText('Ben Ito already picked up this shift.')).toBeTruthy()
  expect(mocked.week).toHaveBeenCalledTimes(2)
})

test('next week asks the server for the following Sunday', async () => {
  mocked.week.mockResolvedValue(week())
  await render(<MyWeek employee={ana} onSwitch={() => {}} />)
  await fireEvent.press(await screen.findByText('Next week'))
  await waitFor(() => expect(mocked.week).toHaveBeenLastCalledWith(1, '2026-11-29'))
})
