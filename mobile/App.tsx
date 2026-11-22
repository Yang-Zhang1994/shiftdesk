import { useState } from 'react'
import { SafeAreaView, StyleSheet } from 'react-native'
import { StatusBar } from 'expo-status-bar'
import { MyWeek } from './src/screens/MyWeek'
import { PickEmployee } from './src/screens/PickEmployee'
import type { Employee } from './src/types'

export default function App() {
  const [me, setMe] = useState<Employee | null>(null)
  return (
    <SafeAreaView style={styles.root}>
      {me ? <MyWeek employee={me} onSwitch={() => setMe(null)} /> : <PickEmployee onPick={setMe} />}
      <StatusBar style="dark" />
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({ root: { flex: 1, backgroundColor: 'white' } })
