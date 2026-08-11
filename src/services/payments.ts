import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  Payment,
  PaymentKind,
  PaymentMethod,
  PaymentStatus,
  PaymentTotals,
} from '@/lib/types'
import { mockPayments } from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo } from './base'
import { recordAudit } from './audit'

const demoPayments: Payment[] = [...mockPayments]

export interface PaymentQuery {
  search: string
  status: PaymentStatus | 'all'
  method: PaymentMethod | 'all'
  kind: PaymentKind | 'all'
  /** Days back from today, or `all` for the whole ledger. */
  days: number | 'all'
  page: number
  pageSize: number
}

function withinRange(payment: Payment, days: number | 'all'): boolean {
  if (days === 'all') return true
  return payment.created_at >= isoDaysAgo(days)
}

function matches(payment: Payment, query: PaymentQuery): boolean {
  if (query.status !== 'all' && payment.status !== query.status) return false
  if (query.method !== 'all' && payment.method !== query.method) return false
  if (query.kind !== 'all' && payment.kind !== query.kind) return false
  if (!withinRange(payment, query.days)) return false

  const term = query.search.trim().toLowerCase()
  if (!term) return true
  return (
    payment.reference.toLowerCase().includes(term) ||
    payment.user_name.toLowerCase().includes(term) ||
    payment.provider_name.toLowerCase().includes(term) ||
    payment.gateway_ref.toLowerCase().includes(term)
  )
}

export async function listPayments(query: PaymentQuery): Promise<Paged<Payment>> {
  if (!isSupabaseConfigured) {
    const filtered = demoPayments.filter((payment) => matches(payment, query))
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('payments')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.method !== 'all') builder = builder.eq('method', query.method)
  if (query.kind !== 'all') builder = builder.eq('kind', query.kind)
  if (query.days !== 'all') builder = builder.gte('created_at', isoDaysAgo(query.days))

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,gateway_ref.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Payment[], total: count ?? 0 }
}

function summarise(payments: Payment[]): PaymentTotals {
  const settled = payments.filter((payment) => payment.status === 'paid')
  const refunded = payments.filter((payment) => payment.status === 'refunded')
  // A pending payment has not resolved either way, so it is left out of the
  // success rate rather than counted as a failure.
  const resolved = payments.filter((payment) => payment.status !== 'pending')

  const byMethod = new Map<PaymentMethod, number>()
  for (const payment of settled) {
    byMethod.set(payment.method, (byMethod.get(payment.method) ?? 0) + payment.amount)
  }

  return {
    collected: settled.reduce((sum, payment) => sum + payment.amount, 0),
    platformShare: settled.reduce((sum, payment) => sum + payment.platform_share, 0),
    refunded: refunded.reduce((sum, payment) => sum + payment.amount, 0),
    refundedCount: refunded.length,
    successRate: resolved.length === 0 ? 0 : settled.length / resolved.length,
    byMethod: [...byMethod]
      .map(([method, amount]) => ({ method, amount }))
      .sort((a, b) => b.amount - a.amount),
  }
}

/**
 * Totals for the current filter, computed over every matching row rather than
 * the page on screen — a KPI that only covered page 1 would be worse than none.
 */
export async function getPaymentTotals(
  query: Omit<PaymentQuery, 'page' | 'pageSize'>,
): Promise<PaymentTotals> {
  if (!isSupabaseConfigured) {
    const filtered = demoPayments.filter((payment) =>
      matches(payment, { ...query, page: 0, pageSize: 0 }),
    )
    return delay(summarise(filtered))
  }

  const client = requireSupabase()
  let builder = client.from('payments').select('amount, platform_share, method, status')

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.method !== 'all') builder = builder.eq('method', query.method)
  if (query.kind !== 'all') builder = builder.eq('kind', query.kind)
  if (query.days !== 'all') builder = builder.gte('created_at', isoDaysAgo(query.days))

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,gateway_ref.ilike.%${safe}%`,
    )
  }

  const { data, error } = await builder
  if (error) throw error
  return summarise((data ?? []) as Payment[])
}

/** Payments belonging to one user or one provider, newest first. */
export async function listPaymentsFor(
  scope: 'user' | 'provider',
  id: string,
): Promise<Payment[]> {
  const column = scope === 'user' ? 'user_id' : 'provider_id'

  if (!isSupabaseConfigured) {
    return delay(
      demoPayments.filter((payment) =>
        scope === 'user' ? payment.user_id === id : payment.provider_id === id,
      ),
    )
  }

  const { data, error } = await requireSupabase()
    .from('payments')
    .select('*')
    .eq(column, id)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Payment[]
}

export async function refundPayment(payment: Payment): Promise<void> {
  const refunded_at = new Date().toISOString()

  if (!isSupabaseConfigured) {
    const target = demoPayments.find((candidate) => candidate.id === payment.id)
    if (target) {
      target.status = 'refunded'
      target.refunded_at = refunded_at
    }
    await delay(null, 400)
  } else {
    const { error } = await requireSupabase()
      .from('payments')
      .update({ status: 'refunded', refunded_at })
      .eq('id', payment.id)
      // Guard against refunding twice if two admins act at once: the row only
      // matches while it is still marked paid.
      .eq('status', 'paid')
    if (error) throw error
  }

  await recordAudit({
    action: 'payment.refund',
    entity: 'payment',
    entityId: payment.id,
    entityLabel: payment.reference,
    details: { amount: payment.amount, user: payment.user_name },
  })
}

export const PAYMENT_STATUS_LABEL: Record<PaymentStatus, string> = {
  paid: 'ناجحة',
  pending: 'معلّقة',
  failed: 'فاشلة',
  refunded: 'مسترجعة',
}

export const PAYMENT_METHOD_LABEL: Record<PaymentMethod, string> = {
  card: 'بطاقة ائتمانية',
  mada: 'مدى',
  apple_pay: 'Apple Pay',
  stc_pay: 'stc pay',
  wallet: 'محفظة التطبيق',
}

export const PAYMENT_KIND_LABEL: Record<PaymentKind, string> = {
  order: 'طلب خدمة',
  subscription: 'اشتراك',
  topup: 'شحن محفظة',
}
