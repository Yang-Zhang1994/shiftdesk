import type { Employee, Location, Shift, Week } from './types'

// On a phone, set EXPO_PUBLIC_API_URL to the laptop's LAN address, e.g. http://192.168.1.20:3000.
const BASE = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000'

export class ApiError extends Error {
  readonly status: number
  readonly messages: string[]

  constructor(status: number, messages: string[]) {
    super(messages.join(' '))
    this.status = status
    this.messages = messages
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}/api${path}`, init)
  const body = await res.json().catch(() => ({}))
  if (!res.ok) throw new ApiError(res.status, body.errors ?? [`Request failed (${res.status})`])
  return body as T
}

export const api = {
  locations: () => request<Location[]>('/locations'),
  employees: (locationId: number) => request<Employee[]>(`/locations/${locationId}/employees`),
  week: (employeeId: number, week?: string) =>
    request<Week>(`/employees/${employeeId}/week${week ? `?week=${week}` : ''}`),
  claim: (employeeId: number, shiftId: number) =>
    request<{ shift: Shift; warnings: string[] }>(`/employees/${employeeId}/claims/${shiftId}`, { method: 'POST' }),
}
