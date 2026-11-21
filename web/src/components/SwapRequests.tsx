import { useState } from 'react'
import { api, ApiError } from '../api'
import { clock, dayLabel, localDate } from '../time'
import type { SwapRequest } from '../types'

interface Props {
  swaps: SwapRequest[]
  /** Called after a decision, with any warnings (the swap then leaves this pending list). */
  onDecided: (warnings: string[]) => void
}

export function SwapRequests({ swaps, onDecided }: Props) {
  const [errors, setErrors] = useState<Record<number, string[]>>({})

  const decide = async (swap: SwapRequest, approve: boolean) => {
    try {
      if (approve) {
        const res = await api.approveSwap(swap.id)
        onDecided(res.warnings)
      } else {
        await api.rejectSwap(swap.id, 'Rejected by manager')
        onDecided([])
      }
    } catch (e) {
      const text = e instanceof ApiError ? e.messages : ['Could not reach the server.']
      setErrors((m) => ({ ...m, [swap.id]: text }))
    }
  }

  if (swaps.length === 0) return <p className="empty">No swap requests waiting.</p>

  return (
    <ul className="swaps">
      {swaps.map((s) => {
        const day = localDate(s.shift.starts_local)
        return (
          <li key={s.id}>
            <p>
              <strong>{s.from_employee.name}</strong> asks <strong>{s.to_employee.name}</strong> to cover{' '}
              {dayLabel(day)}, {clock(s.shift.starts_local)}–{clock(s.shift.ends_local)} ({s.shift.role.replace('_', ' ')})
            </p>
            {s.status === 'pending' ? (
              <div className="actions">
                <button type="button" onClick={() => decide(s, true)}>Approve</button>
                <button type="button" className="secondary" onClick={() => decide(s, false)}>Reject</button>
              </div>
            ) : (
              <p className="status">{s.status}</p>
            )}
            {errors[s.id] && (
              <ul className="messages error" role="alert">
                {errors[s.id].map((t) => <li key={t}>{t}</li>)}
              </ul>
            )}
          </li>
        )
      })}
    </ul>
  )
}
