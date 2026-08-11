import { requireSupabase } from '@/lib/supabase'
import type { AdminAccount, AdminRole } from '@/lib/types'
import { mockAdmins } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoAdmins: AdminAccount[] = [...mockAdmins]

const DEMO_ROLE_KEY = 'demo-role'

/**
 * Overridden by the demo-mode role preview so gating can be seen at work.
 * Persisted, because a preview that silently resets to owner on the next reload
 * makes the gating look broken rather than demonstrated.
 */
function readDemoRole(): AdminRole | null {
  const stored = localStorage.getItem(DEMO_ROLE_KEY)
  return stored === 'owner' || stored === 'admin' || stored === 'viewer' ? stored : null
}

export async function listAdmins(): Promise<AdminAccount[]> {
  if (!isSupabaseConfigured) return delay([...demoAdmins])

  const { data, error } = await requireSupabase()
    .from('admins')
    .select('*')
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as AdminAccount[]
}

/**
 * The signed-in admin's role.
 *
 * Returns `null` when the account exists in auth but has no row in `admins` —
 * signed in, but not authorised. Callers treat that as "no access" rather than
 * silently downgrading to viewer.
 */
export async function getMyRole(userId: string): Promise<AdminRole | null> {
  if (!isSupabaseConfigured) {
    return delay(readDemoRole() ?? 'owner', 60)
  }

  const { data, error } = await requireSupabase()
    .from('admins')
    .select('role')
    .eq('user_id', userId)
    .maybeSingle()
  if (error) throw error
  return (data?.role as AdminRole | undefined) ?? null
}

export async function setAdminRole(admin: AdminAccount, role: AdminRole): Promise<void> {
  // Read first: the demo store mutates the object this argument points at.
  const previous = admin.role

  if (!isSupabaseConfigured) {
    const target = demoAdmins.find((candidate) => candidate.user_id === admin.user_id)
    if (target) target.role = role
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('admins')
      .update({ role })
      .eq('user_id', admin.user_id)
    if (error) throw error
  }

  await recordAudit({
    action: 'admin.role',
    entity: 'admin',
    entityId: admin.user_id,
    entityLabel: admin.email,
    details: { from: ROLE_LABEL[previous], to: ROLE_LABEL[role] },
  })
}

/** Demo-mode only: preview the UI as a different role. */
export function setDemoRole(role: AdminRole) {
  localStorage.setItem(DEMO_ROLE_KEY, role)
}

export const ROLE_LABEL: Record<AdminRole, string> = {
  owner: 'مالك',
  admin: 'مسؤول',
  viewer: 'مطّلع',
}

export const ROLE_DESCRIPTION: Record<AdminRole, string> = {
  owner: 'كل الصلاحيات، بما فيها إدارة المسؤولين.',
  admin: 'تعديل كل البيانات، دون إدارة المسؤولين.',
  viewer: 'قراءة فقط — لا يستطيع تعديل أي شيء.',
}

/** Can this role change data? Mirrors `can_write()` in the RLS policies. */
export const canWrite = (role: AdminRole | null): boolean =>
  role === 'owner' || role === 'admin'

/** Can this role manage other admins? Mirrors `is_owner()`. */
export const canManageAdmins = (role: AdminRole | null): boolean => role === 'owner'
