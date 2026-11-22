import { addDays, byDay, clock, dayLabel, hours, money } from '../format'

test('dayLabel reads the calendar date, not the device time zone', () => {
  expect(dayLabel('2026-11-23T09:00')).toBe('Mon 23 Nov')
  expect(dayLabel('2026-11-28T23:30')).toBe('Sat 28 Nov')
  expect(dayLabel('2026-11-22')).toBe('Sun 22 Nov')
})

test('clock shows wall-clock time as sent by the server', () => {
  expect(clock('2026-11-23T09:00')).toBe('9:00a')
  expect(clock('2026-11-23T17:30')).toBe('5:30p')
  expect(clock('2026-11-23T00:15')).toBe('12:15a')
  expect(clock('2026-11-23T12:00')).toBe('12:00p')
})

test('hours and money', () => {
  expect(hours(450)).toBe('7.5 h')
  expect(money(12900)).toBe('$129.00')
})

test('byDay groups shifts by local start date in order', () => {
  const shifts = [{ starts_local: '2026-11-23T09:00' }, { starts_local: '2026-11-23T18:00' }, { starts_local: '2026-11-24T09:00' }]
  expect(byDay(shifts).map(([d, s]) => [d, s.length])).toEqual([['2026-11-23', 2], ['2026-11-24', 1]])
})

test('addDays crosses month ends on calendar dates', () => {
  expect(addDays('2026-11-29', 7)).toBe('2026-12-06')
  expect(addDays('2026-11-22', 7)).toBe('2026-11-29')
})
