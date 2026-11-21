import { useCallback, useEffect, useState } from 'react'
import { api, ApiError } from './api'
import { PayrollTable } from './components/PayrollTable'
import { ShiftForm } from './components/ShiftForm'
import { SwapRequests } from './components/SwapRequests'
import { WeekSchedule } from './components/WeekSchedule'
import { dayLabel, nextDay } from './time'
import type { Location, Payroll, Schedule, Shift, SwapRequest } from './types'
import './App.css'

type Tab = 'schedule' | 'payroll' | 'swaps'

export default function App() {
  const [location, setLocation] = useState<Location | null>(null)
  const [week, setWeek] = useState(() => new Date().toISOString().slice(0, 10))
  const [tab, setTab] = useState<Tab>('schedule')
  const [schedule, setSchedule] = useState<Schedule | null>(null)
  const [payroll, setPayroll] = useState<Payroll | null>(null)
  const [swaps, setSwaps] = useState<SwapRequest[]>([])
  const [notice, setNotice] = useState<{ kind: 'error' | 'warning'; text: string[] } | null>(null)

  useEffect(() => {
    api.locations()
      .then((ls) => setLocation(ls[0] ?? null))
      .catch(() => setNotice({ kind: 'error', text: ['Could not reach the API. Is `bin/rails server` running?'] }))
  }, [])

  const refresh = useCallback(async () => {
    if (!location) return
    const [s, p, w] = await Promise.all([
      api.schedule(location.id, week),
      api.payroll(location.id, week),
      api.swaps(location.id),
    ])
    setSchedule(s)
    setPayroll(p)
    setSwaps(w)
  }, [location, week])

  useEffect(() => {
    refresh().catch((e) => setNotice({ kind: 'error', text: e instanceof ApiError ? e.messages : [String(e)] }))
  }, [refresh])

  const cancel = async (shift: Shift) => {
    await api.cancelShift(shift.id)
    await refresh()
  }

  const swapDecided = async (warnings: string[]) => {
    setNotice(warnings.length ? { kind: 'warning', text: warnings.map((w) => `Approved, but: ${w}`) } : null)
    await refresh()
  }

  if (!location || !schedule || !payroll) {
    return <main className="app">{notice ? <p className="messages error">{notice.text}</p> : <p>Loading…</p>}</main>
  }

  return (
    <main className="app">
      <header>
        <div>
          <h1>ShiftDesk</h1>
          <p className="sub">{location.name} · {location.time_zone}</p>
        </div>
        <nav className="week" aria-label="Week">
          <button type="button" className="secondary" onClick={() => setWeek(nextDay(schedule.week_start, -7))}>← Previous</button>
          <span>Week of {dayLabel(schedule.week_start)}</span>
          <button type="button" className="secondary" onClick={() => setWeek(nextDay(schedule.week_start, 7))}>Next →</button>
        </nav>
      </header>

      <div className="tabs" role="tablist">
        {(['schedule', 'payroll', 'swaps'] as Tab[]).map((t) => (
          <button key={t} type="button" role="tab" aria-selected={tab === t} onClick={() => setTab(t)}>
            {t === 'schedule' ? 'Schedule' : t === 'payroll' ? 'Payroll' : `Swap requests${swaps.length ? ` (${swaps.length})` : ''}`}
          </button>
        ))}
      </div>

      {notice && (
        <ul className={`messages ${notice.kind}`} role={notice.kind === 'error' ? 'alert' : 'status'}>
          {notice.text.map((t) => <li key={t}>{t}</li>)}
        </ul>
      )}

      {tab === 'schedule' && (
        <>
          <ShiftForm locationId={location.id} days={schedule.days}
            employees={schedule.employees} onSaved={refresh} />
          <WeekSchedule schedule={schedule} onCancel={cancel} />
        </>
      )}
      {tab === 'payroll' && <PayrollTable payroll={payroll} />}
      {tab === 'swaps' && <SwapRequests swaps={swaps} onDecided={swapDecided} />}
    </main>
  )
}
