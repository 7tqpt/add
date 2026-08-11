import { requireSupabase } from '@/lib/supabase'
import type { Audience, NotificationStatus, PushNotification } from '@/lib/types'
import { mockNotifications } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

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

export async function listNotifications(): Promise<PushNotification[]> {
  if (!isSupabaseConfigured) return delay([...demoNotifications])

  const { data, error } = await requireSupabase()
    .from('push_notifications')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100)
  if (error) throw error
  return (data ?? []) as PushNotification[]
}

export async function createNotification(draft: NotificationDraft): Promise<PushNotification> {
  const status: NotificationStatus = draft.scheduledAt ? 'scheduled' : 'sent'

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
