// Formatting works on the server's wall-clock strings ("2026-11-23T09:00") by splitting them, so
// a phone with stale time zone data still shows the right hours (see the README's time zone bug).

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** "2026-11-23T09:00" → "Mon 23 Nov". The weekday comes from the calendar date alone (UTC math). */
export function dayLabel(local: string): string {
  const [y, m, d] = local.slice(0, 10).split('-').map(Number)
  const weekday = new Date(Date.UTC(y, m - 1, d)).getUTCDay()
  return `${DAYS[weekday]} ${d} ${MONTHS[m - 1]}`
}

/** "2026-11-23T09:00" → "9:00a", "…T17:30" → "5:30p". */
export function clock(local: string): string {
  const [h, min] = local.slice(11, 16).split(':').map(Number)
  return `${h % 12 || 12}:${String(min).padStart(2, '0')}${h < 12 ? 'a' : 'p'}`
}

export const hours = (minutes: number) => `${(minutes / 60).toFixed(1)} h`
export const money = (cents: number) => `$${(cents / 100).toFixed(2)}`

/** Shifts grouped by their local start date, in order. */
export function byDay<T extends { starts_local: string }>(shifts: T[]): [string, T[]][] {
  const groups = new Map<string, T[]>()
  for (const s of shifts) {
    const key = s.starts_local.slice(0, 10)
    groups.set(key, [...(groups.get(key) ?? []), s])
  }
  return [...groups.entries()]
}

/** "2026-11-22" + 7 → "2026-11-29", on calendar dates only. */
export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10)
}
