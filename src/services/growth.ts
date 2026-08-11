import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  Promotion,
  PromotionKind,
  PromotionStatus,
  SubscriptionPlan,
} from '@/lib/types'
import { mockPromotions, mockSubscriptionPlans } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoSubscriptions: SubscriptionPlan[] = [...mockSubscriptionPlans]
const demoPromotions: Promotion[] = [...mockPromotions].sort(
  (a, b) => new Date(b.starts_at).getTime() - new Date(a.starts_at).getTime(),
)

// ---------------------------------------------------------------------------
// باقات الاشتراك
// ---------------------------------------------------------------------------

export async function listSubscriptionPlans(): Promise<SubscriptionPlan[]> {
  if (!isSupabaseConfigured) return delay([...demoSubscriptions])

  const { data, error } = await requireSupabase()
    .from('subscription_plans')
    .select('*')
    .order('price', { ascending: true })
  if (error) throw error
  return (data ?? []) as SubscriptionPlan[]
}

export async function setSubscriptionPlanActive(
  plan: SubscriptionPlan,
  is_active: boolean,
): Promise<void> {
  const previous = plan.is_active

  if (!isSupabaseConfigured) {
    const target = demoSubscriptions.find((candidate) => candidate.id === plan.id)
    if (target) target.is_active = is_active
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('subscription_plans')
      .update({ is_active })
      .eq('id', plan.id)
    if (error) throw error
  }

  await recordAudit({
    action: is_active ? 'subscription.activate' : 'subscription.deactivate',
    entity: 'subscription',
    entityId: plan.id,
    entityLabel: plan.name,
    details: {
      from: previous ? 'متاحة' : 'موقوفة',
      to: is_active ? 'متاحة' : 'موقوفة',
      subscribers: plan.subscribers_count,
    },
  })
}

// ---------------------------------------------------------------------------
// الحملات الترويجية
// ---------------------------------------------------------------------------

export interface PromotionQuery {
  search: string
  status: PromotionStatus | 'all'
  kind: PromotionKind | 'all'
  page: number
  pageSize: number
}

export async function listPromotions(query: PromotionQuery): Promise<Paged<Promotion>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoPromotions.filter((promotion) => {
      if (query.status !== 'all' && promotion.status !== query.status) return false
      if (query.kind !== 'all' && promotion.kind !== query.kind) return false
      if (!term) return true
      return (
        promotion.provider_name.toLowerCase().includes(term) ||
        promotion.placement.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    .from('promotions')
    .select('*', { count: 'exact' })
    .order('starts_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.kind !== 'all') builder = builder.eq('kind', query.kind)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`provider_name.ilike.%${safe}%,placement.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Promotion[], total: count ?? 0 }
}

export async function cancelPromotion(promotion: Promotion, reason: string): Promise<void> {
  const previous = promotion.status

  if (!isSupabaseConfigured) {
    const target = demoPromotions.find((candidate) => candidate.id === promotion.id)
    if (target) target.status = 'cancelled'
    await delay(null, 260)
  } else {
    const { error } = await requireSupabase()
      .from('promotions')
      .update({ status: 'cancelled' })
      .eq('id', promotion.id)
      // A finished campaign cannot be cancelled retroactively.
      .in('status', ['scheduled', 'active'])
    if (error) throw error
  }

  await recordAudit({
    action: 'promotion.cancel',
    entity: 'promotion',
    entityId: promotion.id,
    entityLabel: `${PROMOTION_KIND_LABEL[promotion.kind]} — ${promotion.provider_name}`,
    details: {
      from: PROMOTION_STATUS_LABEL[previous],
      to: PROMOTION_STATUS_LABEL.cancelled,
      ...(reason ? { reason } : {}),
      amount: promotion.amount,
    },
  })
}

/** Click-through rate; zero impressions means "not measured", not 0%. */
export function clickRate(promotion: Promotion): number | null {
  return promotion.impressions === 0 ? null : promotion.clicks / promotion.impressions
}

export const PROMOTION_KIND_LABEL: Record<PromotionKind, string> = {
  featured: 'إبراز في النتائج',
  banner: 'لافتة إعلانية',
  category_top: 'صدارة القسم',
}

export const PROMOTION_STATUS_LABEL: Record<PromotionStatus, string> = {
  scheduled: 'مجدولة',
  active: 'جارية',
  ended: 'منتهية',
  cancelled: 'ملغاة',
}
