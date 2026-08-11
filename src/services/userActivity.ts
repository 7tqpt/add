import { requireSupabase } from '@/lib/supabase'
import type { Payment, UserDevice, UserSession } from '@/lib/types'
import { mockUserDevices, mockUserSessions } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { listPaymentsFor } from './payments'

export interface UserActivity {
  sessions: UserSession[]
  devices: UserDevice[]
  payments: Payment[]
}

/** Everything the user-detail screen shows below the profile header. */
export async function getUserActivity(userId: string): Promise<UserActivity> {
  if (!isSupabaseConfigured) {
    const [sessions, devices, payments] = await Promise.all([
      delay(
        mockUserSessions
          .filter((row) => row.user_id === userId)
          .sort((a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime())
          .slice(0, 20),
      ),
      delay(mockUserDevices.filter((row) => row.user_id === userId)),
      listPaymentsFor('user', userId),
    ])
    return { sessions, devices, payments }
  }

  const client = requireSupabase()
  const [sessions, devices, payments] = await Promise.all([
    client
      .from('user_sessions')
      .select('*')
      .eq('user_id', userId)
      .order('started_at', { ascending: false })
      .limit(20),
    client
      .from('user_devices')
      .select('*')
      .eq('user_id', userId)
      .order('last_used_at', { ascending: false }),
    listPaymentsFor('user', userId),
  ])

  if (sessions.error) throw sessions.error
  if (devices.error) throw devices.error

  return {
    sessions: (sessions.data ?? []) as UserSession[],
    devices: (devices.data ?? []) as UserDevice[],
    payments,
  }
}
