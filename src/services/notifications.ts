import { requireSupabase } from '@/lib/supabase'
import type { Audience, NotificationStatus, Paged, PushNotification } from '@/lib/types'
import { mockNotifications } from '@/data/mock'
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
  const status: NotificationStatus = draft.scheduledAt ? 'scheduled' : 'sent'
  const created = await insertNotification(draft, status)

  await recordAudit({
    action: draft.scheduledAt ? 'notification.schedule' : 'notification.send',
    entity: 'notification',
    entityId: created.id,
    entityLabel: created.title,
    details: { audience: draft.audience, scheduled_at: draft.scheduledAt },
  })

  return created
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
      sent_at: draft.scheduledAt ? null : new Date().toISOString(),
      // Delivery counts come from the push provider; demo mode leaves them at
      // zero rather than inventing a reach figure.
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
      sent_at: draft.scheduledAt ? null : new Date().toISOString(),
    })
    .select()
    .single()
  if (error) throw error
  return data as PushNotification
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
