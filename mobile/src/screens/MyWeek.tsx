import { useCallback, useEffect, useRef, useState } from 'react'
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native'
import { api, ApiError } from '../api'
import { addDays, byDay, clock, dayLabel, hours, money } from '../format'
import type { Employee, Shift, Week } from '../types'

type Notice = { kind: 'ok' | 'warn' | 'error'; text: string }

export function MyWeek({ employee, onSwitch }: { employee: Employee; onSwitch: () => void }) {
  const [week, setWeek] = useState<Week | null>(null)
  // The server decides which Sunday "this week" starts on; remembered after the first load.
  const thisWeek = useRef<string | null>(null)
  const [showing, setShowing] = useState<'this' | 'next'>('this')
  const [loading, setLoading] = useState(false)
  const [claiming, setClaiming] = useState<number | null>(null)
  const [notice, setNotice] = useState<Notice | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const start = thisWeek.current
      const result = await api.week(employee.id, start && showing === 'next' ? addDays(start, 7) : start ?? undefined)
      setWeek(result)
      thisWeek.current ??= result.week_start
    } catch (e) {
      setNotice({ kind: 'error', text: (e as Error).message })
    } finally {
      setLoading(false)
    }
  }, [employee.id, showing])

  useEffect(() => { load() }, [load])

  async function pickUp(shift: Shift) {
    setClaiming(shift.id)
    setNotice(null)
    try {
      const { warnings } = await api.claim(employee.id, shift.id)
      setNotice(warnings.length
        ? { kind: 'warn', text: `Picked up. ${warnings.join(' ')}` }
        : { kind: 'ok', text: `Picked up ${dayLabel(shift.starts_local)}, ${clock(shift.starts_local)}–${clock(shift.ends_local)}.` })
    } catch (e) {
      // 409: someone else got it first, or it clashes with one of my shifts. Show why, then refresh.
      setNotice({ kind: 'error', text: e instanceof ApiError ? e.messages.join(' ') : (e as Error).message })
    } finally {
      setClaiming(null)
      await load()
    }
  }

  if (!week) return <ActivityIndicator style={{ marginTop: 40 }} />

  return (
    <ScrollView contentContainerStyle={styles.wrap} refreshControl={<RefreshControl refreshing={loading} onRefresh={load} />}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>{employee.name}</Text>
          <Text style={styles.sub}>{week.location.name} · week of {dayLabel(week.week_start)}</Text>
        </View>
        <Pressable accessibilityRole="button" onPress={onSwitch}><Text style={styles.link}>Switch</Text></Pressable>
      </View>

      <View style={styles.tabs}>
        {(['this', 'next'] as const).map((w) => (
          <Pressable key={w} accessibilityRole="tab" accessibilityState={{ selected: showing === w }}
            style={[styles.tab, showing === w && styles.tabOn]} onPress={() => setShowing(w)}>
            <Text style={showing === w ? styles.tabOnText : undefined}>{w === 'this' ? 'This week' : 'Next week'}</Text>
          </Pressable>
        ))}
      </View>

      {notice && <Text testID="notice" style={[styles.notice, styles[notice.kind]]}>{notice.text}</Text>}

      <View style={styles.card}>
        <Text style={styles.big}>{hours(week.pay.total_minutes)}</Text>
        <Text style={styles.sub}>
          {showing === 'this' ? 'this week' : 'next week'} · about {money(week.pay.gross_cents)} before deductions
          {week.pay.overtime_minutes > 0 ? ` · ${hours(week.pay.overtime_minutes)} overtime` : ''}
        </Text>
      </View>

      <Text style={styles.section}>My shifts</Text>
      {week.shifts.length === 0 && <Text style={styles.sub}>No shifts this week.</Text>}
      {byDay(week.shifts).map(([day, shifts]) => (
        <View key={day} style={styles.row}>
          <Text style={styles.day}>{dayLabel(day)}</Text>
          <Text>{shifts.map((s) => `${clock(s.starts_local)}–${clock(s.ends_local)}`).join(', ')}</Text>
        </View>
      ))}

      <Text style={styles.section}>Open shifts you can pick up</Text>
      {week.open_shifts.length === 0 && <Text style={styles.sub}>Nothing open for your role right now.</Text>}
      {week.open_shifts.map((s) => (
        <View key={s.id} style={styles.row}>
          <Text style={styles.day}>{dayLabel(s.starts_local)}</Text>
          <Text style={{ flex: 1 }}>{clock(s.starts_local)}–{clock(s.ends_local)} · {hours(s.minutes)}</Text>
          <Pressable accessibilityRole="button" accessibilityLabel={`Pick up ${dayLabel(s.starts_local)} ${clock(s.starts_local)}`}
            disabled={claiming !== null} style={styles.button} onPress={() => pickUp(s)}>
            <Text style={styles.buttonText}>{claiming === s.id ? '…' : 'Pick up'}</Text>
          </Pressable>
        </View>
      ))}
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  wrap: { padding: 16, gap: 8 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  title: { fontSize: 22, fontWeight: '600' },
  sub: { color: '#6b7280' },
  link: { color: '#2563eb', fontSize: 16 },
  tabs: { flexDirection: 'row', gap: 8, marginTop: 8 },
  tab: { borderRadius: 16, borderWidth: 1, borderColor: '#d1d5db', paddingHorizontal: 14, paddingVertical: 6 },
  tabOn: { backgroundColor: '#111827', borderColor: '#111827' },
  tabOnText: { color: 'white' },
  card: { backgroundColor: '#f3f4f6', borderRadius: 10, padding: 14, marginTop: 8 },
  big: { fontSize: 28, fontWeight: '700' },
  section: { fontSize: 17, fontWeight: '600', marginTop: 16 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10, borderBottomWidth: 1, borderColor: '#e5e7eb' },
  day: { width: 96, fontWeight: '500' },
  button: { backgroundColor: '#2563eb', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8 },
  buttonText: { color: 'white', fontWeight: '600' },
  notice: { borderRadius: 8, padding: 10 },
  ok: { backgroundColor: '#dcfce7', color: '#166534' },
  warn: { backgroundColor: '#fef3c7', color: '#92400e' },
  error: { backgroundColor: '#fee2e2', color: '#991b1b' },
})
