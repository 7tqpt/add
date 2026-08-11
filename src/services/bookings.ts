import { requireSupabase } from '@/lib/supabase'
import type { Booking, BookingStatus, Paged, Payment, RefundRule } from '@/lib/types'
import { mockBookings, mockPayments } from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo } from './base'
import { recordAudit } from './audit'

const demoBookings: Booking[] = [...mockBookings].sort(
  (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
)

export interface BookingQuery {
  search: string
  status: BookingStatus | 'all'
  category: string | 'all'
  governorate: string | 'all'
  days: number | 'all'
  page: number
  pageSize: number
}

function matches(booking: Booking, query: BookingQuery): boolean {
  if (query.status !== 'all' && booking.status !== query.status) return false
  if (query.category !== 'all' && booking.category_name !== query.category) return false
  if (query.governorate !== 'all' && booking.governorate !== query.governorate) return false
  if (query.days !== 'all' && booking.created_at < isoDaysAgo(query.days)) return false

  const term = query.search.trim().toLowerCase()
  if (!term) return true
  return (
    booking.reference.toLowerCase().includes(term) ||
    booking.user_name.toLowerCase().includes(term) ||
    booking.provider_name.toLowerCase().includes(term) ||
    booking.service_title.toLowerCase().includes(term)
  )
}

export async function listBookings(query: BookingQuery): Promise<Paged<Booking>> {
  if (!isSupabaseConfigured) {
    const filtered = demoBookings.filter((booking) => matches(booking, query))
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('bookings')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.category !== 'all') builder = builder.eq('category_name', query.category)
  if (query.governorate !== 'all') builder = builder.eq('governorate', query.governorate)
  if (query.days !== 'all') builder = builder.gte('created_at', isoDaysAgo(query.days))

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,service_title.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Booking[], total: count ?? 0 }
}

export async function getBooking(id: string): Promise<Booking | null> {
  if (!isSupabaseConfigured) {
    return delay(demoBookings.find((booking) => booking.id === id) ?? null)
  }

  const { data, error } = await requireSupabase()
    .from('bookings')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as Booking | null) ?? null
}

export async function listBookingPayments(bookingId: string): Promise<Payment[]> {
  if (!isSupabaseConfigured) {
    return delay(
      mockPayments
        .filter((payment) => payment.booking_id === bookingId)
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()),
    )
  }

  const { data, error } = await requireSupabase()
    .from('payments')
    .select('*')
    .eq('booking_id', bookingId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as Payment[]
}

/**
 * What would be returned if this booking were cancelled right now, per the
 * ladder copied into it at booking time. Mirrors `refundable_amount()` in SQL —
 * the dashboard shows the figure before the admin confirms.
 */
export function refundableNow(booking: Booking): number {
  const hoursLeft = (new Date(booking.event_date).getTime() - Date.now()) / 3_600_000
  const rules: RefundRule[] = booking.cancellation_rules ?? []
  // السلّم تنازلي؛ أول عتبة يتجاوزها الوقت المتبقي هي المطبَّقة.
  const rule = rules.find((entry) => hoursLeft >= entry.hours_before)
  return Math.round((booking.paid_amount * (rule?.refund_percent ?? 0)) / 100)
}

// ---------------------------------------------------------------------------
// تضارب المواعيد
// ---------------------------------------------------------------------------

/** حجزان أو أكثر على مقدّم الخدمة نفسه في وقت متداخل. */
export interface Conflict {
  provider_id: string
  provider_name: string
  event_date: string
  bookings: Booking[]
}

/** A booking that still needs the slot: cancelled ones free it again. */
const holdsSlot = (booking: Booking) =>
  booking.status === 'pending_provider' || booking.status === 'confirmed'

/** Minutes from midnight; a missing time is treated as the whole evening. */
function startMinutes(booking: Booking): number | null {
  if (!booking.event_time) return null
  const [h, m] = booking.event_time.split(':').map(Number)
  return Number.isNaN(h) ? null : h * 60 + (m || 0)
}

/**
 * Two bookings clash when the same provider is due at both, on the same day,
 * within `windowHours` of each other — a wedding is not a slot you can leave
 * halfway through, so near-simultaneous is as bad as identical.
 *
 * A booking with no stated time is assumed to occupy the day, because a
 * provider cannot be in two places without one.
 */
export function findConflicts(bookings: Booking[], windowHours = 4): Conflict[] {
  const byKey = new Map<string, Booking[]>()
  for (const booking of bookings) {
    if (!holdsSlot(booking)) continue
    const key = `${booking.provider_id}|${booking.event_date}`
    byKey.set(key, [...(byKey.get(key) ?? []), booking])
  }

  const conflicts: Conflict[] = []
  for (const group of byKey.values()) {
    if (group.length < 2) continue

    const clashing = group.filter((booking) =>
      group.some((other) => {
        if (other.id === booking.id) return false
        const a = startMinutes(booking)
        const b = startMinutes(other)
        if (a === null || b === null) return true
        return Math.abs(a - b) < windowHours * 60
      }),
    )
    if (clashing.length < 2) continue

    conflicts.push({
      provider_id: clashing[0].provider_id,
      provider_name: clashing[0].provider_name,
      event_date: clashing[0].event_date,
      bookings: clashing.sort((a, b) => (a.event_time ?? '').localeCompare(b.event_time ?? '')),
    })
  }

  return conflicts.sort((a, b) => a.event_date.localeCompare(b.event_date))
}

export interface CalendarDay {
  date: string
  bookings: Booking[]
  conflicts: Conflict[]
}

/** الحجوزات القادمة موزّعة على أيامها، مع تعليم أيام التضارب. */
export async function getCalendar(days = 60): Promise<CalendarDay[]> {
  const today = new Date().toISOString().slice(0, 10)
  const until = new Date(Date.now() + days * 86_400_000).toISOString().slice(0, 10)

  let upcoming: Booking[]
  if (!isSupabaseConfigured) {
    upcoming = demoBookings.filter(
      (booking) => booking.event_date >= today && booking.event_date <= until,
    )
  } else {
    const { data, error } = await requireSupabase()
      .from('bookings')
      .select('*')
      .gte('event_date', today)
      .lte('event_date', until)
      .order('event_date', { ascending: true })
    if (error) throw error
    upcoming = (data ?? []) as Booking[]
  }

  const live = upcoming.filter(holdsSlot)
  const conflicts = findConflicts(live)

  const byDate = new Map<string, CalendarDay>()
  for (const booking of live) {
    const day = byDate.get(booking.event_date) ?? {
      date: booking.event_date,
      bookings: [],
      conflicts: [],
    }
    day.bookings.push(booking)
    byDate.set(booking.event_date, day)
  }
  for (const conflict of conflicts) {
    const day = byDate.get(conflict.event_date)
    if (day) day.conflicts.push(conflict)
  }

  const result = [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date))
  return isSupabaseConfigured ? result : delay(result)
}

/**
 * Admin intervention on a booking. The customer and provider drive the normal
 * path from the apps; the dashboard steps in when something is stuck or
 * disputed, so every change here is logged with a reason.
 */
export async function setBookingStatus(
  booking: Booking,
  status: BookingStatus,
  reason = '',
): Promise<void> {
  const previous = booking.status
  const now = new Date().toISOString()
  const patch: Partial<Booking> = { status }

  if (status === 'confirmed') patch.confirmed_at = now
  if (status === 'completed') patch.completed_at = now
  if (status === 'cancelled') {
    patch.cancelled_at = now
    patch.cancel_reason = reason || 'أُلغي من لوحة التحكم.'
    patch.refunded_amount = refundableNow(booking)
  }
  if (status === 'rejected') {
    patch.cancelled_at = now
    patch.rejection_reason = reason || 'رُفض من لوحة التحكم.'
    patch.refunded_amount = booking.paid_amount
  }

  if (!isSupabaseConfigured) {
    const target = demoBookings.find((candidate) => candidate.id === booking.id)
    if (target) Object.assign(target, patch)
    await delay(null, 280)
  } else {
    const { error } = await requireSupabase().from('bookings').update(patch).eq('id', booking.id)
    if (error) throw error
  }

  await recordAudit({
    action: `booking.${status}`,
    entity: 'booking',
    entityId: booking.id,
    entityLabel: booking.reference,
    details: {
      from: BOOKING_STATUS_LABEL[previous],
      to: BOOKING_STATUS_LABEL[status],
      ...(reason ? { reason } : {}),
      ...(patch.refunded_amount ? { amount: patch.refunded_amount } : {}),
    },
  })
}

export const BOOKING_STATUS_LABEL: Record<BookingStatus, string> = {
  pending_provider: 'بانتظار مقدّم الخدمة',
  confirmed: 'مؤكد',
  completed: 'منفّذ',
  rejected: 'مرفوض',
  cancelled: 'ملغي',
  expired: 'منتهي',
}

/** المسار الطبيعي للحجز، لعرض شريط التقدّم. */
export const BOOKING_TRAIL: BookingStatus[] = ['pending_provider', 'confirmed', 'completed']
