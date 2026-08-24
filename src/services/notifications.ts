import { requireSupabase } from '@/lib/supabase'
import type { Audience, NotificationStatus, Paged, PushNotification } from '@/lib/types'
import { mockNotifications, mockUsers } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

export interface NotificationDraft {
  title: string
  body: string
  audience: Audience
  /** ISO timestamp when scheduling; null sends immediately. */
  scheduledAt: string | null
}

const demoNotifications: PushNotification[] = [...mockNotifications].sort(sortByRecency)

function timestampOf(notification: PushNotification): number {
  const stamp = notification.sent_at ?? notification.scheduled_at
  return stamp ? new Date(stamp).getTime() : 0
}

function sortByRecency(a: PushNotification, b: PushNotification): number {
  return timestampOf(b) - timestampOf(a)
}

export async function listNotifications(
  page: number,
  pageSize: number,
): Promise<Paged<PushNotification>> {
  if (!isSupabaseConfigured) {
    const start = page * pageSize
    return delay({
      rows: demoNotifications.slice(start, start + pageSize),
      total: demoNotifications.length,
    })
  }

  const from = page * pageSize
  const { data, error, count } = await requireSupabase()
    .from('push_notifications')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + pageSize - 1)
  if (error) throw error
  return { rows: (data ?? []) as PushNotification[], total: count ?? 0 }
}

export async function createNotification(draft: NotificationDraft): Promise<PushNotification> {
  // **الصفُّ يُكتب مسوّدةً ثم يُرسَل، لا يُكتب «مُرسلاً».**
  //
  // كان يُكتب بحالة `sent` وينتهي الأمر — ولا أحد يقرأ ذلك الجدول: لا التطبيق
  // ولا دالّةُ الدفع. فالمسؤول يقرأ «مُرسل ✅» ولا يصل أحداً شيء. والإرسال
  // الحقيقي في `api_admin_broadcast`: تتفرّق الحملة صفوفاً في صناديق جمهورها،
  // فتوقظ كلَّ واحدةٍ منها طريقَ الدفع إلى الجوال.
  const created = await insertNotification(draft, draft.scheduledAt ? 'scheduled' : 'draft')
  const sent = draft.scheduledAt ? created : await sendNotification(created)

  await recordAudit({
    action: draft.scheduledAt ? 'notification.schedule' : 'notification.send',
    entity: 'notification',
    entityId: sent.id,
    entityLabel: sent.title,
    details: {
      audience: draft.audience,
      scheduled_at: draft.scheduledAt,
      recipients: sent.recipients,
    },
  })

  return sent
}

/**
 * يُرسل حملةً قائمة — للمجدولة التي حان وقتها ولم يُرسلها جدول القاعدة، ولمن
 * أراد تقديمها.
 *
 * والعدد الراجع من القاعدة هو عدد الصناديق التي وصلتها فعلاً: لا يُقدَّر هنا
 * ولا يُحسب من صفٍّ في الواجهة.
 */
export async function sendNotification(
  notification: PushNotification,
): Promise<PushNotification> {
  if (!isSupabaseConfigured) {
    const reached = demoAudienceSize(notification.audience)
    const index = demoNotifications.findIndex((row) => row.id === notification.id)
    const updated: PushNotification = {
      ...notification,
      status: 'sent',
      sent_at: new Date().toISOString(),
      recipients: reached,
    }
    if (index >= 0) demoNotifications[index] = updated
    return delay(updated, 420)
  }

  const client = requireSupabase()
  const { data, error } = await client.rpc('api_admin_broadcast', { p_id: notification.id })
  if (error) throw error

  const { data: row } = await client
    .from('push_notifications')
    .select('*')
    .eq('id', notification.id)
    .single()
  return (row as PushNotification | null) ?? {
    ...notification,
    status: 'sent',
    sent_at: new Date().toISOString(),
    recipients: Number(data ?? 0),
  }
}

/** جمهور الحملة في وضع العرض — تُحسب من المستخدمين الوهميين لا تُخترع. */
function demoAudienceSize(audience: Audience): number {
  const month = Date.now() - 30 * 24 * 60 * 60 * 1000
  const live = mockUsers.filter((user) => user.status !== 'suspended')
  const seen = (iso: string | null) => (iso ? new Date(iso).getTime() : 0)
  switch (audience) {
    case 'all':
      return live.length
    case 'ios':
    case 'android':
      return live.filter((user) => user.platform === audience).length
    case 'active':
      return live.filter((user) => seen(user.last_seen_at) >= month).length
    case 'inactive':
      return live.filter((user) => seen(user.last_seen_at) < month).length
    // بيانات العرض لا تربط المزوّدين بحساباتهم، فلا سبيل إلى فرزٍ صادق هنا.
    case 'providers':
    case 'customers':
      return live.length
  }
}

async function insertNotification(
  draft: NotificationDraft,
  status: NotificationStatus,
): Promise<PushNotification> {
  if (!isSupabaseConfigured) {
    const created: PushNotification = {
      id: `ntf_${Date.now().toString(36)}`,
      title: draft.title,
      body: draft.body,
      audience: draft.audience,
      status,
      scheduled_at: draft.scheduledAt,
      // لا ختم إرسالٍ عند الإنشاء — الختم أثرُ فعلٍ وقع، لا نيّةٍ عُقدت.
      sent_at: null,
      // العدد يأتي من القاعدة عند الإرسال، ولا يُخترع هنا.
      recipients: 0,
      opened: 0,
    }
    demoNotifications.unshift(created)
    return delay(created, 420)
  }

  const { data, error } = await requireSupabase()
    .from('push_notifications')
    .insert({
      title: draft.title,
      body: draft.body,
      audience: draft.audience,
      status,
      scheduled_at: draft.scheduledAt,
      // **بقيّةُ الشيفرة القديمة، وكانت تُبطل الإرسال كلَّه.**
      //
      // حين صار الصفُّ يُكتب «مسوّدة» ثم يُرسَل بالدالّة، بقي هذا السطر يختم
      // `sent_at` وقت الإنشاء. فتُولد الحملة موسومةً بأنها أُرسلت، ثم يردّها
      // حارسُ التكرار في `api_admin_broadcast` بـ«أُرسلت هذه الحملة من قبل».
      // والختم أثرُ فعلٍ وقع لا نيّةٍ عُقدت، فمن يضعه قبل الفعل يكذب على نفسه.
      sent_at: null,
    })
    .select()
    .single()
  if (error) throw error
  return data as PushNotification
}

/**
 * يُفرّغ سجل الحملات في اللوحة — ولا يمسّ صناديق المستخدمين.
 *
 * **والفرق جوهريّ:** الحملة تتفرّق صفوفاً في صناديق الناس ساعةَ الإرسال، وتلك
 * صارت ملكَهم — تُقرأ في جرس التطبيق وقد بُني عليها. فهذا تنظيفُ دفترٍ عندنا
 * لا تعديلٌ في ماضي غيرنا. والقاعدة هي التي تتحقّق من الصلاحية لا هذه الدالّة.
 *
 * يُعيد عدد ما أُزيل.
 */
export async function clearNotificationLog(): Promise<number> {
  if (!isSupabaseConfigured) {
    const removed = demoNotifications.length
    demoNotifications.length = 0
    await delay(null, 420)
    await recordAudit({
      action: 'notification.purge',
      entity: 'notification',
      entityId: '',
      entityLabel: 'سجل الإشعارات',
      details: { removed },
    })
    return removed
  }

  const { data, error } = await requireSupabase().rpc('api_clear_push_log')
  if (error) {
    // الدالّة أحدثُ من بعض القواعد: رسالةٌ تقول أيَّ ملفٍ يُشغَّل أنفعُ من رمز
    // خطأٍ لا يدلّ على شيء.
    if (error.code === 'PGRST202') {
      throw new Error(
        'الدالة api_clear_push_log غير موجودة في قاعدتك — شغّل ' +
          'supabase/broadcast.sql في محرّر SQL ثم أعد تحميل الصفحة.',
      )
    }
    throw error
  }
  // السجلّ في القاعدة هو المصدر، والأثر يُكتب هناك — فلا `recordAudit` هنا.
  return (data as number) ?? 0
}

export const AUDIENCE_LABEL: Record<Audience, string> = {
  all: 'كل المستخدمين',
  customers: 'العملاء',
  providers: 'مقدّمو الخدمة',
  ios: 'مستخدمو iOS',
  android: 'مستخدمو Android',
  active: 'المستخدمون النشطون',
  inactive: 'المستخدمون غير النشطين',
}

export const NOTIFICATION_STATUS_LABEL: Record<NotificationStatus, string> = {
  sent: 'مُرسل',
  scheduled: 'مجدول',
  draft: 'مسودة',
  failed: 'فشل',
}
