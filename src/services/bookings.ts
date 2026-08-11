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
