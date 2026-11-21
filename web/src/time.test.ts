import { describe, expect, it } from 'vitest'
import { clock, dayLabel, hours, localDate, money, nextDay, shiftTimes } from './time'

describe('shiftTimes', () => {
  it('sends wall-clock times; the server applies the location time zone', () => {
    expect(shiftTimes('2026-11-23', '09:00', '17:00')).toEqual({ starts_at: '2026-11-23T09:00', ends_at: '2026-11-23T17:00' })
  })

  it('ends the next morning when the end is earlier than the start', () => {
    expect(shiftTimes('2026-11-27', '22:00', '06:00')).toEqual({ starts_at: '2026-11-27T22:00', ends_at: '2026-11-28T06:00' })
  })

  it('rolls over months and years', () => {
    expect(shiftTimes('2026-12-31', '22:00', '06:00').ends_at).toBe('2027-01-01T06:00')
  })
})

describe('display helpers', () => {
  it("shows the server's local times without converting zones", () => {
    expect(clock('2026-11-23T09:00')).toBe('9:00a')
    expect(clock('2026-11-23T00:30')).toBe('12:30a')
    expect(clock('2026-11-23T12:00')).toBe('12:00p')
    expect(clock('2026-11-23T17:45')).toBe('5:45p')
    expect(localDate('2026-11-23T22:30')).toBe('2026-11-23')
  })

  it('labels dates the same in every browser time zone', () => {
    expect(dayLabel('2026-11-22')).toBe('Sun, Nov 22')
  })

  it('formats hours, money and week steps', () => {
    expect(hours(480)).toBe('8')
    expect(hours(450)).toBe('7.5')
    expect(money(104000)).toBe('$1,040.00')
    expect(nextDay('2026-11-28')).toBe('2026-11-29')
    expect(nextDay('2026-11-22', -7)).toBe('2026-11-15')
  })
})
