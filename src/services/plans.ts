import { requireSupabase } from '@/lib/supabase'
import type { Booking, Paged, PlanStatus, WeddingPlan } from '@/lib/types'
import { mockBookings, mockPlans } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'

const demoPlans: WeddingPlan[] = [...mockPlans].sort(
  (a, b) => new Date(a.wedding_date).getTime() - new Date(b.wedding_date).getTime(),
)

export interface PlanQuery {
  search: string
  status: PlanStatus | 'all'
  governorate: string | 'all'
  page: number
  pageSize: number
}

export async function listPlans(query: PlanQuery): Promise<Paged<WeddingPlan>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoPlans.filter((plan) => {
      if (query.status !== 'all' && plan.status !== query.status) return false
      if (query.governorate !== 'all' && plan.governorate !== query.governorate) return false
      if (!term) return true
      return (
        plan.title.toLowerCase().includes(term) || plan.user_name.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    // The view carries the computed totals; the table stores only the plan.
    .from('v_plan_summary')
    .select('*', { count: 'exact' })
    .order('wedding_date', { ascending: true })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.governorate !== 'all') builder = builder.eq('governorate', query.governorate)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`title.ilike.%${safe}%,user_name.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as WeddingPlan[], total: count ?? 0 }
}

export async function getPlan(id: string): Promise<WeddingPlan | null> {
  if (!isSupabaseConfigured) return delay(demoPlans.find((plan) => plan.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('v_plan_summary')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as WeddingPlan | null) ?? null
}

/** The services booked under one wedding, in the order they will happen. */
export async function listPlanBookings(planId: string): Promise<Booking[]> {
  if (!isSupabaseConfigured) {
    return delay(
      mockBookings
        .filter((booking) => booking.plan_id === planId)
        .sort((a, b) => a.event_date.localeCompare(b.event_date)),
    )
  }

  const { data, error } = await requireSupabase()
    .from('bookings')
    .select('*')
    .eq('plan_id', planId)
    .order('event_date', { ascending: true })
  if (error) throw error
  return (data ?? []) as Booking[]
}

export const PLAN_STATUS_LABEL: Record<PlanStatus, string> = {
  planning: 'قيد التجهيز',
  confirmed: 'مكتملة الحجز',
  completed: 'منتهية',
  cancelled: 'ملغاة',
}

/** Days until the wedding; negative once it has passed. */
export function daysUntil(isoDate: string): number {
  const target = new Date(isoDate).setHours(0, 0, 0, 0)
  const today = new Date().setHours(0, 0, 0, 0)
  return Math.round((target - today) / 86_400_000)
}
