import { requireSupabase } from '@/lib/supabase'
import type { Booking, DailyBreakdown, DashboardStats, MetricPoint, RangeDays } from '@/lib/types'
import {
  mockActiveByDay,
  mockBookings,
  mockBookingsByDay,
  mockDisputes,
  mockInstallsByDay,
  mockProviders,
  mockRevenueByDay,
  mockReviews,
  mockSettlements,
} from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo, lastDays, periodChange, sum } from './base'

function tally<T extends string>(items: T[]): Map<T, number> {
  const counts = new Map<T, number>()
  for (const item of items) counts.set(item, (counts.get(item) ?? 0) + 1)
  return counts
}

/** الحجوزات الفعّالة فقط: الملغي والمرفوض لا يمثّلان طلباً على القسم. */
const isLive = (booking: Booking) =>
  booking.status === 'pending_provider' ||
  booking.status === 'confirmed' ||
  booking.status === 'completed'

interface Series {
  installs: DailyBreakdown[]
  bookings: MetricPoint[]
  revenue: MetricPoint[]
  active: MetricPoint[]
  commission: MetricPoint[]
  categories: string[]
  governorates: string[]
  queue: Queue
}

/** ما ينتظر تدخّل الإدارة الآن — يُعرض كتنبيهات لا كمؤشرات اتجاه. */
interface Queue {
  pendingProviders: number
  openDisputes: number
  pendingSettlements: number
  flaggedReviews: number
}

/**
 * Assembles every figure the dashboard shows for the selected range.
 *
 * Each KPI carries its own change vs. the preceding window of equal length, so
 * the series are fetched at twice the range and split rather than fetched twice.
 */
export async function getDashboardStats(range: RangeDays): Promise<DashboardStats> {
  if (isSupabaseConfigured) return fromSupabase(range)
  return delay(buildStats(range, demoSeries()))
}

function demoSeries(): Series {
  const live = mockBookings.filter(isLive)
  return {
    installs: mockInstallsByDay,
    bookings: mockBookingsByDay,
    revenue: mockRevenueByDay,
    active: mockActiveByDay,
    // The platform's own take, not the gross the couple paid.
    commission: mockRevenueByDay.map((point) => ({
      date: point.date,
      value: Math.round(point.value * 0.1),
    })),
    categories: live.map((booking) => booking.category_name),
    governorates: live.map((booking) => booking.governorate),
    queue: {
      pendingProviders: mockProviders.filter((p) => p.status === 'pending').length,
      openDisputes: mockDisputes.filter(
        (d) => d.status === 'open' || d.status === 'investigating',
      ).length,
      pendingSettlements: mockSettlements.filter((s) => s.status === 'pending').length,
      flaggedReviews: mockReviews.filter((r) => r.status === 'flagged').length,
    },
  }
}

function buildStats(range: RangeDays, series: Series): DashboardStats {
  const bookingValues = series.bookings.map((point) => point.value)
  const revenueValues = series.revenue.map((point) => point.value)
  const commissionValues = series.commission.map((point) => point.value)
  const activeValues = series.active.map((point) => point.value)
  const activeWindow = lastDays(activeValues, range)

  return {
    // Average DAU reads as a level, not a total — summing daily actives would
    // double-count anyone who opened the app on more than one day.
    activeUsers: {
      value: activeWindow.length ? Math.round(sum(activeWindow) / activeWindow.length) : 0,
      change: periodChange(activeValues, range),
    },
    bookings: {
      value: sum(lastDays(bookingValues, range)),
      change: periodChange(bookingValues, range),
    },
    revenue: {
      value: sum(lastDays(revenueValues, range)),
      change: periodChange(revenueValues, range),
    },
    commission: {
      value: sum(lastDays(commissionValues, range)),
      change: periodChange(commissionValues, range),
    },
    bookingsByDay: lastDays(series.bookings, range),
    installsByDay: lastDays(series.installs, range),
    bookingsByCategory: [...tally(series.categories)]
      .map(([category, count]) => ({ category, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6),
    topGovernorates: [...tally(series.governorates)]
      .map(([governorate, bookings]) => ({ governorate, bookings }))
      .sort((a, b) => b.bookings - a.bookings)
      .slice(0, 5),
    ...series.queue,
  }
}

interface MetricRow {
  day: string
  platform: 'ios' | 'android'
  installs: number
  active_users: number
}

async function fromSupabase(range: RangeDays): Promise<DashboardStats> {
  const client = requireSupabase()
  // Twice the range so each KPI can compare against the preceding window.
  const since = isoDaysAgo(range * 2)

  const [metrics, bookings, queue] = await Promise.all([
    client
      .from('daily_metrics')
      .select('day, platform, installs, active_users')
      .gte('day', since)
      .order('day', { ascending: true }),
    client
      .from('bookings')
      .select('created_at, status, total_price, commission_amount, category_name, governorate')
      .gte('created_at', since),
    loadQueue(),
  ])

  if (metrics.error) throw metrics.error
  if (bookings.error) throw bookings.error

  const installsByDay = new Map<string, DailyBreakdown>()
  const activeByDay = new Map<string, number>()
  for (const row of (metrics.data ?? []) as MetricRow[]) {
    const entry = installsByDay.get(row.day) ?? { date: row.day, ios: 0, android: 0 }
    entry[row.platform] += row.installs
    installsByDay.set(row.day, entry)
    activeByDay.set(row.day, (activeByDay.get(row.day) ?? 0) + row.active_users)
  }

  type Row = Pick<
    Booking,
    'created_at' | 'status' | 'total_price' | 'commission_amount' | 'category_name' | 'governorate'
  >
  const rows = ((bookings.data ?? []) as Row[]).filter((row) => isLive(row as Booking))

  const bookingsByDay = new Map<string, number>()
  const revenueByDay = new Map<string, number>()
  const commissionByDay = new Map<string, number>()
  for (const row of rows) {
    const day = row.created_at.slice(0, 10)
    bookingsByDay.set(day, (bookingsByDay.get(day) ?? 0) + 1)
    revenueByDay.set(day, (revenueByDay.get(day) ?? 0) + Number(row.total_price))
    commissionByDay.set(day, (commissionByDay.get(day) ?? 0) + Number(row.commission_amount))
  }

  // One axis for every series, so a day with no bookings is a zero rather than
  // a gap that shifts the line.
  const days = [
    ...new Set([...installsByDay.keys(), ...bookingsByDay.keys()]),
  ].sort()
  const pointsFrom = (source: Map<string, number>): MetricPoint[] =>
    days.map((date) => ({ date, value: source.get(date) ?? 0 }))

  return buildStats(range, {
    installs: days.map((date) => installsByDay.get(date) ?? { date, ios: 0, android: 0 }),
    bookings: pointsFrom(bookingsByDay),
    revenue: pointsFrom(revenueByDay),
    commission: pointsFrom(commissionByDay),
    active: pointsFrom(activeByDay),
    categories: rows.map((row) => row.category_name),
    governorates: rows.map((row) => row.governorate),
    queue,
  })
}

async function loadQueue(): Promise<Queue> {
  const client = requireSupabase()
  const count = { count: 'exact' as const, head: true }

  const [providers, disputes, settlements, reviews] = await Promise.all([
    client.from('service_providers').select('id', count).eq('status', 'pending'),
    client.from('disputes').select('id', count).in('status', ['open', 'investigating']),
    client.from('settlements').select('id', count).eq('status', 'pending'),
    client.from('reviews').select('id', count).eq('status', 'flagged'),
  ])

  return {
    pendingProviders: providers.count ?? 0,
    openDisputes: disputes.count ?? 0,
    pendingSettlements: settlements.count ?? 0,
    flaggedReviews: reviews.count ?? 0,
  }
}
