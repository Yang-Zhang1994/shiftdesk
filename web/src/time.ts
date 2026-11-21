// The server owns time zones: the browser sends wall-clock times at the location ("2026-11-23T09:00")
// and shows the local times the server sends back. A browser's own time zone data can be out of date
// (see README), so nothing here converts between zones.

/** "09:00" -> "17:00" is the same day; "22:00" -> "06:00" ends the next morning. */
export function shiftTimes(date: string, from: string, to: string) {
  const endDate = to > from ? date : nextDay(date)
  return { starts_at: `${date}T${from}`, ends_at: `${endDate}T${to}` }
}

export function nextDay(date: string, days = 1): string {
  const d = new Date(`${date}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** Date part of a local "YYYY-MM-DDTHH:MM" string. */
export const localDate = (local: string) => local.slice(0, 10)

/** "2026-11-23T09:00" -> "9:00a", "2026-11-23T17:30" -> "5:30p". */
export function clock(local: string): string {
  const [h, m] = local.slice(11, 16).split(':').map(Number)
  return `${h % 12 || 12}:${String(m).padStart(2, '0')}${h < 12 ? 'a' : 'p'}`
}

/** Calendar label for a date string, independent of the browser's time zone. */
export function dayLabel(date: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC', weekday: 'short', day: 'numeric', month: 'short' })
    .format(new Date(`${date}T12:00:00Z`))
}

export const hours = (minutes: number) => (minutes / 60).toFixed(1).replace(/\.0$/, '')

export const money = (cents: number) =>
  new Intl.NumberFormat('en-CA', { style: 'currency', currency: 'CAD' }).format(cents / 100)
