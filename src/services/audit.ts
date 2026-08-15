import { requireSupabase } from '@/lib/supabase'
import type { AuditEntry, Paged } from '@/lib/types'
import { delay, isSupabaseConfigured } from './base'

/**
 * Who is performing the current action. Set once by `AuthProvider` whenever the
 * session changes, so mutation helpers can stamp the log without every screen
 * having to thread the signed-in admin down into its service calls.
 */
let actorEmail = ''

export function setAuditActor(email: string) {
  actorEmail = email
}

export interface AuditDraft {
  action: string
  entity: string
  entityId: string
  entityLabel: string
  details?: Record<string, unknown>
}

const DEMO_LOG_KEY = 'demo-audit-log'
/** Keeps the demo log from growing without bound in localStorage. */
const DEMO_LOG_LIMIT = 200

/**
 * In demo mode the log lives in localStorage rather than memory: an audit trail
 * that empties on every page reload cannot show what an audit trail is for.
 */
function readDemoLog(): AuditEntry[] {
  try {
    const raw = localStorage.getItem(DEMO_LOG_KEY)
    return raw ? (JSON.parse(raw) as AuditEntry[]) : []
  } catch {
    return []
  }
}

function writeDemoLog(entries: AuditEntry[]) {
  try {
    localStorage.setItem(DEMO_LOG_KEY, JSON.stringify(entries.slice(0, DEMO_LOG_LIMIT)))
  } catch (cause) {
    console.error('تعذّر حفظ سجل العمليات التجريبي:', cause)
  }
}

/**
 * Appends one entry to the audit log.
 *
 * Deliberately never throws: an audit write failing must not roll back or mask
 * the change the admin actually made. A failure is reported to the console and
 * swallowed.
 */
export async function recordAudit(draft: AuditDraft): Promise<void> {
  const entry: AuditEntry = {
    id: `aud_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
    actor_email: actorEmail,
    action: draft.action,
    entity: draft.entity,
    entity_id: draft.entityId,
    entity_label: draft.entityLabel,
    details: draft.details ?? {},
    created_at: new Date().toISOString(),
  }

  if (!isSupabaseConfigured) {
    writeDemoLog([entry, ...readDemoLog()])
    return
  }

  try {
    const { error } = await requireSupabase().from('audit_log').insert({
      actor_email: entry.actor_email,
      action: entry.action,
      entity: entry.entity,
      entity_id: entry.entity_id,
      entity_label: entry.entity_label,
      details: entry.details,
    })
    if (error) throw error
  } catch (cause) {
    console.error('تعذّر تسجيل العملية في سجل المراجعة:', cause)
  }
}

export interface AuditQuery {
  entity: string | 'all'
  search: string
  page: number
  pageSize: number
}

export async function listAudit(query: AuditQuery): Promise<Paged<AuditEntry>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = readDemoLog().filter((entry) => {
      if (query.entity !== 'all' && entry.entity !== query.entity) return false
      if (!term) return true
      return (
        entry.actor_email.toLowerCase().includes(term) ||
        entry.entity_label.toLowerCase().includes(term) ||
        entry.action.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('audit_log')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.entity !== 'all') builder = builder.eq('entity', query.entity)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`actor_email.ilike.%${safe}%,entity_label.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as AuditEntry[], total: count ?? 0 }
}

export const AUDIT_ENTITY_LABEL: Record<string, string> = {
  user: 'مستخدم',
  provider: 'مقدّم خدمة',
  booking: 'حجز',
  payment: 'عملية دفع',
  settlement: 'تسوية مستحقات',
  dispute: 'نزاع',
  review: 'تقييم',
  category: 'قسم خدمات',
  service: 'خدمة',
  policy: 'سياسة إلغاء',
  promotion: 'حملة ترويجية',
  subscription: 'باقة اشتراك',
  notification: 'إشعار',
  version: 'إصدار',
  settings: 'إعدادات',
  admin: 'مسؤول',
}

export const AUDIT_ACTION_LABEL: Record<string, string> = {
  'user.suspend': 'إيقاف مستخدم',
  'user.activate': 'تفعيل مستخدم',

  'provider.verified': 'توثيق مقدّم خدمة',
  'provider.rejected': 'رفض مقدّم خدمة',
  'provider.suspended': 'إيقاف مقدّم خدمة',
  'provider.pending': 'إعادة مقدّم خدمة للمراجعة',
  'provider.commission': 'تغيير نسبة العمولة',
  'provider.document': 'مراجعة مستند',

  'booking.confirmed': 'تأكيد حجز',
  'booking.completed': 'إغلاق حجز كمنفّذ',
  'booking.cancelled': 'إلغاء حجز',
  'booking.rejected': 'رفض حجز',
  'booking.expired': 'انتهاء مهلة حجز',

  'payment.refund': 'استرجاع مبلغ',
  'settlement.status': 'تغيير حالة تسوية',

  'dispute.reply': 'الرد على نزاع',
  'dispute.investigating': 'فتح تحقيق في نزاع',
  'dispute.resolved': 'حسم نزاع',
  'dispute.closed': 'إغلاق نزاع',
  'dispute.open': 'إعادة فتح نزاع',

  'review.hidden': 'إخفاء تقييم',
  'review.published': 'نشر تقييم',
  'review.flagged': 'تعليم تقييم للمراجعة',

  'category.activate': 'تفعيل قسم',
  'category.deactivate': 'تعطيل قسم',
  'service.publish': 'عرض خدمة',
  'service.unpublish': 'إخفاء خدمة',
  'policy.update': 'تعديل سياسة إلغاء',

  'promotion.cancel': 'إلغاء حملة ترويجية',
  'subscription.activate': 'إتاحة باقة اشتراك',
  'subscription.deactivate': 'إيقاف باقة اشتراك',

  'notification.send': 'إرسال إشعار',
  'notification.schedule': 'جدولة إشعار',
  'version.force_update': 'تغيير التحديث الإجباري',
  'version.rollout': 'تغيير نسبة الطرح',
  'settings.update': 'تحديث الإعدادات',
  'admin.role': 'تغيير دور مسؤول',
  'audit.purge': 'تفريغ سجل العمليات',
}

/**
 * يُفرِّغ سجل العمليات — للمالك وحده، والقاعدة هي التي تتحقّق لا الواجهة.
 *
 * والجدول يبقى بلا سياسة حذف: التفريغ دالةٌ `security definer` تتجاوز
 * السياسات بعد أن تتأكّد من المالك، فلا يُفتح الحذف الانتقائي لأي جلسة.
 *
 * ويُخلّف التفريغ أثره — صفٌّ يقول من فرّغ وكم أزال — فلا يخرج السجل منه
 * فارغاً بل شاهداً على أنه فُرِّغ. يُعيد عدد ما أُزيل.
 */
export async function clearAuditLog(): Promise<number> {
  if (!isSupabaseConfigured) {
    const removed = readDemoLog().length
    const actor = 'demo-admin@aras.ye'
    writeDemoLog([
      {
        id: `demo-purge-${Date.now()}`,
        actor_email: actor,
        action: 'audit.purge',
        entity: 'audit_log',
        entity_id: '',
        entity_label: 'سجل العمليات',
        details: { removed },
        created_at: new Date().toISOString(),
      },
    ])
    return delay(removed)
  }

  const { data, error } = await requireSupabase().rpc('api_clear_audit_log')
  if (error) {
    if (error.code === 'PGRST202' || /api_clear_audit_log/.test(error.message)) {
      throw new Error('قاعدة البيانات لم تُحدَّث بعد — شغّل supabase/roles.sql ثم أعد المحاولة.')
    }
    throw new Error(error.message)
  }
  return (data as number) ?? 0
}
