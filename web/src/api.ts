import type { Employee, Location, Payroll, Schedule, Shift, ShiftInput, SwapRequest } from './types'

export class ApiError extends Error {
  status: number
  messages: string[]

  constructor(status: number, messages: string[]) {
    super(messages.join(' '))
    this.status = status
    this.messages = messages
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...init?.headers },
  })
  const body = await res.json().catch(() => ({}))
  if (!res.ok) throw new ApiError(res.status, body.errors ?? [`Request failed (${res.status})`])
  return body as T
}

const post = <T>(path: string, data?: unknown) => request<T>(path, { method: 'POST', body: JSON.stringify(data ?? {}) })

export const api = {
  locations: () => request<Location[]>('/locations'),
  employees: (locationId: number) => request<Employee[]>(`/locations/${locationId}/employees`),
  schedule: (locationId: number, week: string) => request<Schedule>(`/locations/${locationId}/schedule?week=${week}`),
  payroll: (locationId: number, week: string) => request<Payroll>(`/locations/${locationId}/payroll?week=${week}`),
  swaps: (locationId: number, status = 'pending') =>
    request<SwapRequest[]>(`/locations/${locationId}/swap_requests?status=${status}`),
  createShift: (shift: ShiftInput) => post<{ shift: Shift; warnings: string[] }>('/shifts', { shift }),
  cancelShift: (id: number) => request<{ shift: Shift }>(`/shifts/${id}`, { method: 'DELETE' }),
  approveSwap: (id: number) => post<{ swap: SwapRequest; warnings: string[] }>(`/swap_requests/${id}/approve`),
  rejectSwap: (id: number, note: string) => post<{ swap: SwapRequest }>(`/swap_requests/${id}/reject`, { note }),
}
