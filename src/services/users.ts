import { requireSupabase } from '@/lib/supabase'
import type { AppUser, Platform, UserStatus } from '@/lib/types'
import { mockUsers } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

export interface UserQuery {
  search: string
  status: UserStatus | 'all'
  platform: Platform | 'all'
  page: number
  pageSize: number
}

export interface UserPage {
  rows: AppUser[]
  total: number
}

/** Mutated in demo mode so status changes survive navigation within a session. */
const demoUsers: AppUser[] = [...mockUsers].sort(
  (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
)

function matches(user: AppUser, query: UserQuery): boolean {
  if (query.status !== 'all' && user.status !== query.status) return false
  if (query.platform !== 'all' && user.platform !== query.platform) return false
  const term = query.search.trim().toLowerCase()
  if (!term) return true
  return (
    user.full_name.toLowerCase().includes(term) ||
    user.email.toLowerCase().includes(term) ||
    (user.phone ?? '').includes(term)
  )
}

export async function listUsers(query: UserQuery): Promise<UserPage> {
  if (!isSupabaseConfigured) {
    const filtered = demoUsers.filter((user) => matches(user, query))
    const start = query.page * query.pageSize
    return delay({
      rows: filtered.slice(start, start + query.pageSize),
      total: filtered.length,
    })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('app_users')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.platform !== 'all') builder = builder.eq('platform', query.platform)

  const term = query.search.trim()
  if (term) {
    // Commas and parentheses would terminate the `or` filter early.
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`full_name.ilike.%${safe}%,email.ilike.%${safe}%,phone.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as AppUser[], total: count ?? 0 }
}

export async function updateUserStatus(id: string, status: UserStatus): Promise<void> {
  if (!isSupabaseConfigured) {
    const user = demoUsers.find((candidate) => candidate.id === id)
    if (user) user.status = status
    await delay(null, 180)
    return
  }

  const { error } = await requireSupabase().from('app_users').update({ status }).eq('id', id)
  if (error) throw error
}

export const USER_STATUS_LABEL: Record<UserStatus, string> = {
  active: 'نشط',
  suspended: 'موقوف',
  pending: 'بانتظار التفعيل',
}
