import { requireSupabase } from '@/lib/supabase'
import type {
  CancellationPolicy,
  Paged,
  ProviderService,
  ServiceCategory,
} from '@/lib/types'
import { mockCategories, mockPolicies, mockProviders, mockServices } from '@/data/mock'
import { DAY_FORMS, HOUR_FORMS, formatCount } from '@/lib/format'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoCategories: ServiceCategory[] = [...mockCategories]
const demoPolicies: CancellationPolicy[] = [...mockPolicies]
const demoServices: ProviderService[] = [...mockServices]

// ---------------------------------------------------------------------------
// أقسام الخدمات
// ---------------------------------------------------------------------------

/** Providers per category, so an admin can see which sections are still thin. */
function withCounts(categories: ServiceCategory[]): ServiceCategory[] {
  return categories.map((category) => ({
    ...category,
    providers_count: mockProviders.filter(
      (provider) => provider.status === 'verified' && provider.categories.includes(category.name),
    ).length,
  }))
}

export async function listCategories(): Promise<ServiceCategory[]> {
  if (!isSupabaseConfigured) {
    return delay(withCounts(demoCategories).sort((a, b) => a.sort_order - b.sort_order))
  }

  const { data, error } = await requireSupabase()
    .from('service_categories')
    .select('*')
    .order('sort_order', { ascending: true })
  if (error) throw error
  return (data ?? []) as ServiceCategory[]
}

export async function setCategoryActive(
  category: ServiceCategory,
  is_active: boolean,
): Promise<void> {
  if (!isSupabaseConfigured) {
    const target = demoCategories.find((candidate) => candidate.id === category.id)
    if (target) target.is_active = is_active
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('service_categories')
      .update({ is_active })
      .eq('id', category.id)
    if (error) throw error
  }

  await recordAudit({
    action: is_active ? 'category.activate' : 'category.deactivate',
    entity: 'category',
    entityId: category.id,
    entityLabel: category.name,
    details: { from: category.is_active ? 'مفعّل' : 'معطّل', to: is_active ? 'مفعّل' : 'معطّل' },
  })
}

// ---------------------------------------------------------------------------
// الخدمات المعروضة
// ---------------------------------------------------------------------------

export interface ServiceQuery {
  search: string
  category: string | 'all'
  active: 'all' | 'active' | 'inactive'
  page: number
  pageSize: number
}

export async function listServices(query: ServiceQuery): Promise<Paged<ProviderService>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoServices.filter((service) => {
      if (query.category !== 'all' && service.category_name !== query.category) return false
      if (query.active === 'active' && !service.is_active) return false
      if (query.active === 'inactive' && service.is_active) return false
      if (!term) return true
      return (
        service.title.toLowerCase().includes(term) ||
        service.provider_name.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    .from('v_admin_services')
    .select('*', { count: 'exact' })
    .order('title', { ascending: true })
    .range(from, from + query.pageSize - 1)

  if (query.category !== 'all') builder = builder.eq('category_name', query.category)
  if (query.active !== 'all') builder = builder.eq('is_active', query.active === 'active')

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`title.ilike.%${safe}%,provider_name.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as ProviderService[], total: count ?? 0 }
}

export async function setServiceActive(
  service: ProviderService,
  is_active: boolean,
): Promise<void> {
  const previous = service.is_active

  if (!isSupabaseConfigured) {
    const target = demoServices.find((candidate) => candidate.id === service.id)
    if (target) target.is_active = is_active
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('provider_services')
      .update({ is_active })
      .eq('id', service.id)
    if (error) throw error
  }

  await recordAudit({
    action: is_active ? 'service.publish' : 'service.unpublish',
    entity: 'service',
    entityId: service.id,
    entityLabel: `${service.title} — ${service.provider_name}`,
    details: { from: previous ? 'معروضة' : 'مخفية', to: is_active ? 'معروضة' : 'مخفية' },
  })
}

// ---------------------------------------------------------------------------
// سياسات الإلغاء
// ---------------------------------------------------------------------------

export async function listPolicies(): Promise<CancellationPolicy[]> {
  if (!isSupabaseConfigured) return delay([...demoPolicies])

  const { data, error } = await requireSupabase()
    .from('cancellation_policies')
    .select('*')
    .order('name', { ascending: true })
  if (error) throw error
  return (data ?? []) as CancellationPolicy[]
}

/**
 * Services already booked keep the ladder copied into them at booking time, so
 * editing a policy only affects future bookings. Say so where it is edited.
 */
export async function savePolicyRules(
  policy: CancellationPolicy,
  rules: CancellationPolicy['rules'],
): Promise<void> {
  // Descending thresholds: `refundable_amount()` walks the ladder in order and
  // takes the first rule the remaining time clears.
  const sorted = [...rules].sort((a, b) => b.hours_before - a.hours_before)

  if (!isSupabaseConfigured) {
    const target = demoPolicies.find((candidate) => candidate.id === policy.id)
    if (target) target.rules = sorted
    await delay(null, 300)
  } else {
    const { error } = await requireSupabase()
      .from('cancellation_policies')
      .update({ rules: sorted })
      .eq('id', policy.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'policy.update',
    entity: 'policy',
    entityId: policy.id,
    entityLabel: policy.name,
    details: { rules: sorted.length },
  })
}

/** "قبل 3 أيام فأكثر: استرداد 100%" — one rung of the ladder in a readable line. */
export function describeRule(rule: CancellationPolicy['rules'][number]): string {
  // The floor of the ladder: everything below the last threshold, not "0 hours".
  if (rule.hours_before === 0) return `بعد ذلك: استرداد ${rule.refund_percent}%`

  const when =
    rule.hours_before >= 24
      ? `قبل ${formatCount(Math.round(rule.hours_before / 24), DAY_FORMS)} فأكثر`
      : `قبل ${formatCount(rule.hours_before, HOUR_FORMS)} فأكثر`
  return `${when}: استرداد ${rule.refund_percent}%`
}
