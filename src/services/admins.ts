import { requireSupabase } from '@/lib/supabase'
import type { AdminAccount, AdminInvitation, AdminRole } from '@/lib/types'
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
 * يمحو الموظف من القاعدة: صفّ المسؤول، ودعواته، وحساب المصادقة نفسه.
 *
 * وهو غير `removeAdmin`: تلك تسحب الصلاحية وتُبقي الحساب — لأن صاحبه قد يكون
 * عميلاً على التطبيق. وهذه تمحو الحساب، فترفضها القاعدة إن كان له بياناتٌ
 * هناك، لأن الحذف يتسلسل إلى حجوزاته وخططه.
 *
 * ولا أثر يُكتب هنا: الدالة تكتبه داخل معاملتها، فإن تراجعت تراجع معها ولم
 * يبقَ في السجل أثرُ حذفٍ لم يقع.
 */
export async function deleteAdminAccount(admin: AdminAccount): Promise<string> {
  if (!isSupabaseConfigured) {
    const index = demoAdmins.findIndex((candidate) => candidate.user_id === admin.user_id)
    if (index >= 0) demoAdmins.splice(index, 1)
    await delay(null, 260)
    await recordAudit({
      action: 'admin.delete_account',
      entity: 'admin',
      entityId: admin.user_id,
      entityLabel: admin.email,
      details: { from: ROLE_LABEL[admin.role], user: admin.email },
    })
    return admin.email
  }

  const { data, error } = await requireSupabase().rpc('api_delete_admin_account', {
    p_user_id: admin.user_id,
  })
  if (error) {
    if (error.code === 'PGRST202') {
      throw new Error(
        'الدالة api_delete_admin_account غير موجودة في قاعدة بياناتك — شغّل ملف ' +
          'supabase/roles.sql كاملاً في محرّر SQL، ثم أعد تحميل الصفحة.',
      )
    }
    throw new Error(`تعذّر الحذف${error.code ? ` (${error.code})` : ''}: ${error.message}`)
  }
  return (data as string) ?? admin.email
}

/**
 * ينقل ملكية اللوحة إلى مسؤولٍ آخر، ويُنزل الناقل إلى «مدير».
 *
 * نداءٌ واحد لا نداءان: الترقية والتنزيل يقعان معاً في معاملةٍ واحدة داخل
 * القاعدة. ولو فُرِّقا هنا وانقطع الاتصال بينهما لبقيت اللوحة بمالكَين، أو —
 * وهو الأسوأ — بلا مالكٍ أصلاً، ولا أحد يعيد إليها مالكاً من داخلها.
 *
 * ولا يُسجَّل الأثر هنا: الدالة نفسها تكتبه في المعاملة ذاتها، فلا يفترق
 * الحدث عن أثره لو فشل أحدهما. وتسجيلُه هنا أيضاً يُثبته مرّتين.
 *
 * يُعيد بريد المالك الجديد كما تراه القاعدة.
 */
export async function transferOwnership(target: AdminAccount): Promise<string> {
  if (!isSupabaseConfigured) {
    const next = demoAdmins.find((candidate) => candidate.user_id === target.user_id)
    const me = demoAdmins.find((candidate) => candidate.role === 'owner')
    if (next) next.role = 'owner'
    if (me && me.user_id !== target.user_id) me.role = 'manager'
    // في وضع العرض الدور مخزَّنٌ محلياً لا في جدول، فيُنزَّل هناك أيضاً وإلا
    // بقيت الواجهة تُريك أزرار المالك بعد أن تخلّيت عنها.
    setDemoRole('manager')
    await delay(null, 280)
    await recordAudit({
      action: 'admin.ownership',
      entity: 'admin',
      entityId: target.user_id,
      entityLabel: target.email,
      details: { from: me?.email ?? '', to: target.email },
    })
    return target.email
  }

  const { data, error } = await requireSupabase().rpc('api_transfer_ownership', {
    p_target_user_id: target.user_id,
  })
  if (error) {
    if (error.code === 'PGRST202') {
      throw new Error(
        'الدالة api_transfer_ownership غير موجودة في قاعدة بياناتك — شغّل ملف ' +
          'supabase/roles.sql كاملاً في محرّر SQL، ثم أعد تحميل الصفحة.',
      )
    }
    throw new Error(`تعذّر نقل الملكية${error.code ? ` (${error.code})` : ''}: ${error.message}`)
  }
  return (data as string) ?? target.email
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

// ---------------------------------------------------------------------------
// دعوات الموظفين
// ---------------------------------------------------------------------------

const demoInvitations: AdminInvitation[] = []

/** رمز شبيه بما تولّده القاعدة، للوضع التجريبي وحده. */
function demoToken(): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  return Array.from({ length: 10 }, () =>
    alphabet[Math.floor(Math.random() * alphabet.length)],
  ).join('')
}

/**
 * ينشئ دعوةً ويعيد رمزها.
 *
 * لا يُنشأ حساب المصادقة هنا: ذلك يحتاج مفتاح الخدمة، وهو يتجاوز RLS كلها فلا
 * يُسلَّم لمتصفّح. الموظف يسجّل نفسه بالرمز، فيختار كلمة مروره بيده — ولا يعرفها
 * المالك ولا تمرّ في رسالة.
 */
export async function inviteAdmin(
  email: string,
  role: AdminRole,
  note = '',
): Promise<AdminInvitation> {
  if (!isSupabaseConfigured) {
    const now = new Date()
    const invitation: AdminInvitation = {
      id: `inv_${now.getTime().toString(36)}`,
      email: email.trim().toLowerCase(),
      role,
      token: demoToken(),
      invited_by: 'admin@example.com',
      note,
      created_at: now.toISOString(),
      expires_at: new Date(now.getTime() + 7 * 86_400_000).toISOString(),
      accepted_at: null,
      status: 'pending',
    }
    demoInvitations.unshift(invitation)
    await delay(null, 280)
    await recordAudit({
      action: 'admin.invite',
      entity: 'admin',
      entityId: invitation.id,
      entityLabel: invitation.email,
      details: { to: ROLE_LABEL[role] },
    })
    return invitation
  }

  const { data, error } = await requireSupabase().rpc('api_invite_admin', {
    p_email: email.trim(),
    p_role: role,
    p_note: note,
  })
  if (error) throw error

  const invitation = (Array.isArray(data) ? data[0] : data) as AdminInvitation
  await recordAudit({
    action: 'admin.invite',
    entity: 'admin',
    entityId: invitation.id,
    entityLabel: invitation.email,
    details: { to: ROLE_LABEL[role] },
  })
  return { ...invitation, status: 'pending' }
}

export async function listInvitations(): Promise<AdminInvitation[]> {
  if (!isSupabaseConfigured) return delay([...demoInvitations])
  const { data, error } = await requireSupabase()
    .from('v_admin_invitations')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as AdminInvitation[]
}

export async function cancelInvitation(invitation: AdminInvitation): Promise<void> {
  if (!isSupabaseConfigured) {
    const index = demoInvitations.findIndex((candidate) => candidate.id === invitation.id)
    if (index >= 0) demoInvitations.splice(index, 1)
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('admin_invitations')
      .delete()
      .eq('id', invitation.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'admin.invite_cancel',
    entity: 'admin',
    entityId: invitation.id,
    entityLabel: invitation.email,
    details: {},
  })
}

/**
 * هل الدعوة صالحة لهذا البريد؟ — تُستدعى **قبل** إنشاء الحساب.
 *
 * بدونها كان الترتيب: يُنشأ حساب المصادقة ثم تُقبل الدعوة. فرمزٌ خاطئ يُخلّف
 * في Supabase حساباً يتيماً بلا دور، ولا تحذفه اللوحة لأن حذف مستخدمي
 * المصادقة يحتاج `service_role`.
 *
 * وتُعيد `boolean` لا أكثر: سبب الرفض لا يُقال هنا ولا في القاعدة، فالتمييز
 * بين «رمز خاطئ» و«رمز صحيح لبريد آخر» يحوّل النموذج إلى أداة تخمين.
 */
export async function checkInvitation(token: string, email: string): Promise<boolean> {
  const clean = token.trim().toUpperCase()
  if (!isSupabaseConfigured) {
    const match = demoInvitations.find((candidate) => candidate.token === clean)
    await delay(null, 200)
    return Boolean(
      match &&
        !match.accepted_at &&
        match.email.toLowerCase() === email.trim().toLowerCase(),
    )
  }

  const { data, error } = await requireSupabase().rpc('api_check_invitation', {
    p_token: clean,
    p_email: email.trim(),
  })
  if (error) {
    // الدالة حديثة، وقد تُنشر اللوحة قبل تشغيل `invitations.sql` على القاعدة.
    // وحينها يردّ PostgREST بـPGRST202، فتظهر رسالةٌ عامّة لا تدلّ على شيء
    // ويقف التسجيل كلّه بلا سبب ظاهر. الرسالة هنا تقول ما الناقص بالضبط.
    if (error.code === 'PGRST202' || /api_check_invitation/.test(error.message)) {
      throw new Error(
        'قاعدة البيانات لم تُحدَّث بعد — شغّل supabase/invitations.sql في محرّر SQL ثم أعد المحاولة.',
      )
    }
    throw new Error(error.message)
  }
  return data === true
}

/** يستدعيها الموظف بعد أن يسجّل حسابه بالبريد المدعوّ. */
export async function acceptInvitation(token: string): Promise<AdminRole> {
  if (!isSupabaseConfigured) {
    const match = demoInvitations.find(
      (candidate) => candidate.token === token.trim().toUpperCase(),
    )
    if (!match) throw new Error('الدعوة غير صالحة — تأكّد من الرمز.')
    match.accepted_at = new Date().toISOString()
    match.status = 'accepted'
    await delay(null, 300)
    return match.role
  }

  const { data, error } = await requireSupabase().rpc('api_accept_invitation', {
    p_token: token.trim(),
  })
  if (error) {
    // `throw error` وحدها لا تكفي: حين يفشل الطلب على مستوى الشبكة تبني
    // مكتبة PostgREST كائناً بسيطاً بلا صنف `Error`، فيسقط فحص
    // `instanceof Error` عند المستدعي وتُبتلع الرسالة خلف نصٍّ عامّ لا
    // يقول شيئاً. فيُلَفّ الخطأ هنا دائماً، ويُذكر رمزه معه.
    if (error.code === 'PGRST202') {
      throw new Error(
        'الدالة api_accept_invitation غير موجودة في قاعدة بياناتك — شغّل ملف ' +
          'supabase/invitations.sql كاملاً في محرّر SQL، ثم أعد المحاولة.',
      )
    }
    if (/سجّل الدخول أولاً/.test(error.message)) {
      throw new Error('انتهت جلستك. سجّل الخروج ثم ادخل من جديد وأعد إدخال الرمز.')
    }
    if (/حسابك مسؤول بالفعل/.test(error.message)) {
      throw new Error('حسابك مسؤولٌ بالفعل — أعد تحميل الصفحة.')
    }
    if (/الدعوة غير صالحة/.test(error.message)) {
      throw new Error(
        'الرمز لا يطابق دعوةً سارية لهذا البريد. تأكّد أنك سجّلت بالبريد نفسه ' +
          'الذي دُعي، وأن الدعوة لم تنتهِ ولم تُستعمل. واطلب من المالك رمزاً ' +
          'جديداً إن لزم.',
      )
    }
    if (error.code === '42501' || /permission denied/i.test(error.message)) {
      throw new Error(
        'حسابك ممنوع من تنفيذ الدالة — أعد تشغيل سطر GRANT في نهاية ' +
          'supabase/invitations.sql.',
      )
    }
    throw new Error(
      `تعذّر قبول الدعوة${error.code ? ` (${error.code})` : ''}: ${error.message}`,
    )
  }
  return data as AdminRole
}
