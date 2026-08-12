import { requireSupabase } from '@/lib/supabase'
import type { AdminAccount, AdminRole } from '@/lib/types'
import { ROLES_IN_ORDER, ROLE_AREAS, ROLE_LABEL, canWriteArea } from '@/lib/permissions'
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
  return ROLES_IN_ORDER.includes(stored as AdminRole) ? (stored as AdminRole) : null
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

/**
 * يضيف مسؤولاً بحسابٍ موجود في Supabase Auth.
 *
 * لا يُنشئ حساب مصادقة: إنشاء الحسابات يحتاج مفتاح الخدمة، وهو مفتاح يتجاوز
 * RLS كلها فلا يُوضع في صفحة يفتحها متصفّح. المسار الصحيح أن يُنشأ الحساب من
 * Supabase ← Authentication، ثم يُمنح الدور من هنا.
 */
export async function addAdmin(userId: string, email: string, role: AdminRole): Promise<void> {
  if (!isSupabaseConfigured) {
    demoAdmins.push({ user_id: userId, email, role, created_at: new Date().toISOString() })
    await delay(null, 260)
  } else {
    const { error } = await requireSupabase()
      .from('admins')
      .insert({ user_id: userId, email, role })
    if (error) throw error
  }

  await recordAudit({
    action: 'admin.add',
    entity: 'admin',
    entityId: userId,
    entityLabel: email,
    details: { to: ROLE_LABEL[role] },
  })
}

/**
 * يسحب صلاحية الدخول بحذف الصف، لا بحذف الحساب.
 *
 * حساب المصادقة يبقى — قد يكون للشخص نفسه حساب عميل على التطبيق، وحذفه من
 * `auth.users` يمحو حجوزاته معه.
 */
export async function removeAdmin(admin: AdminAccount): Promise<void> {
  if (!isSupabaseConfigured) {
    const index = demoAdmins.findIndex((candidate) => candidate.user_id === admin.user_id)
    if (index >= 0) demoAdmins.splice(index, 1)
    await delay(null, 240)
  } else {
    const { error } = await requireSupabase()
      .from('admins')
      .delete()
      .eq('user_id', admin.user_id)
    if (error) throw error
  }

  await recordAudit({
    action: 'admin.remove',
    entity: 'admin',
    entityId: admin.user_id,
    entityLabel: admin.email,
    details: { from: ROLE_LABEL[admin.role] },
  })
}

/** Demo-mode only: preview the UI as a different role. */
export function setDemoRole(role: AdminRole) {
  localStorage.setItem(DEMO_ROLE_KEY, role)
}

export { ROLE_LABEL, ROLE_DESCRIPTION } from '@/lib/permissions'

/** يكتب في أي مجال — للأزرار العامة. القرار الحقيقي يُتخذ بالمجال. */
export const canWrite = (role: AdminRole | null): boolean =>
  role !== null && Object.values(ROLE_AREAS[role] ?? {}).includes('write')

/** يدير المسؤولين — المالك وحده. */
export const canManageAdmins = (role: AdminRole | null): boolean =>
  canWriteArea(role, 'admins')
