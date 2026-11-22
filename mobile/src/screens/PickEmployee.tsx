import { useEffect, useState } from 'react'
import { ActivityIndicator, FlatList, Pressable, StyleSheet, Text, View } from 'react-native'
import { api } from '../api'
import type { Employee } from '../types'

// There is no sign-in in this demo: you pick who you are, as on a shared tablet in the back office.
export function PickEmployee({ onPick }: { onPick: (e: Employee) => void }) {
  const [people, setPeople] = useState<Employee[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api.locations()
      .then(([first]) => api.employees(first.id))
      .then(setPeople)
      .catch((e: Error) => setError(e.message))
  }, [])

  if (error) return <Text style={styles.error}>Can't reach ShiftDesk: {error}</Text>
  if (!people) return <ActivityIndicator style={{ marginTop: 40 }} />

  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>Who are you?</Text>
      <FlatList
        data={people}
        keyExtractor={(p) => String(p.id)}
        renderItem={({ item }) => (
          <Pressable accessibilityRole="button" style={styles.row} onPress={() => onPick(item)}>
            <Text style={styles.name}>{item.name}</Text>
            <Text style={styles.role}>{item.role.replace('_', ' ')}</Text>
          </Pressable>
        )}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  wrap: { flex: 1, padding: 16 },
  title: { fontSize: 22, fontWeight: '600', marginBottom: 12 },
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 14, borderBottomWidth: 1, borderColor: '#e5e7eb' },
  name: { fontSize: 17 },
  role: { fontSize: 15, color: '#6b7280' },
  error: { padding: 16, color: '#b91c1c' },
})
