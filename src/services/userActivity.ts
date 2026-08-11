import { requireSupabase } from '@/lib/supabase'
import type { Purchase, UserDevice, UserSession } from '@/lib/types'
import { mockPurchases, mockUserDevices, mockUserSessions } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

export interface UserActivity {
  sessions: UserSession[]
  devices: UserDevice[]
  purchases: Purchase[]
}

const byNewest = <T extends { created_at?: string; started_at?: string }>(a: T, b: T) =>
  new Date(b.started_at ?? b.created_at ?? 0).getTime() -
  new Date(a.started_at ?? a.created_at ?? 0).getTime()

/** Everything the user-detail screen shows below the profile header. */
export async function getUserActivity(userId: string): Promise<UserActivity> {
  if (!isSupabaseConfigured) {
    return delay({
      sessions: mockUserSessions.filter((row) => row.user_id === userId).sort(byNewest).slice(0, 20),
      devices: mockUserDevices.filter((row) => row.user_id === userId),
      purchases: mockPurchases.filter((row) => row.user_id === userId).sort(byNewest),
    })
  }

  const client = requireSupabase()
  const [sessions, devices, purchases] = await Promise.all([
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
    client
      .from('purchases')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false }),
  ])

  if (sessions.error) throw sessions.error
  if (devices.error) throw devices.error
  if (purchases.error) throw purchases.error

  return {
    sessions: (sessions.data ?? []) as UserSession[],
    devices: (devices.data ?? []) as UserDevice[],
    purchases: (purchases.data ?? []) as Purchase[],
  }
}

export const PURCHASE_STATUS_LABEL: Record<string, string> = {
  paid: 'مدفوع',
  refunded: 'مسترجع',
  failed: 'فشل',
  pending: 'قيد المعالجة',
}
