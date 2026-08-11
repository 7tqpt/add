import { requireSupabase } from '@/lib/supabase'
import type { Order, OrderOffer, OrderStatus, Paged, Payment } from '@/lib/types'
import { PROVIDER_CATEGORIES, PROVIDER_CITIES, mockOffers, mockOrders } from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo } from './base'
import { recordAudit } from './audit'
import { addPayment, listPaymentsForOrder } from './payments'

const demoOrders: Order[] = [...mockOrders]
const demoOffers: OrderOffer[] = [...mockOffers]

export { PROVIDER_CATEGORIES, PROVIDER_CITIES }

/** The platform's cut of an accepted offer. */
const COMMISSION = 0.15

export interface OrderQuery {
  search: string
  status: OrderStatus | 'all'
  category: string | 'all'
  city: string | 'all'
  days: number | 'all'
  page: number
  pageSize: number
}

function matches(order: Order, query: OrderQuery): boolean {
  if (query.status !== 'all' && order.status !== query.status) return false
  if (query.category !== 'all' && order.category !== query.category) return false
  if (query.city !== 'all' && order.city !== query.city) return false
  if (query.days !== 'all' && order.created_at < isoDaysAgo(query.days)) return false

  const term = query.search.trim().toLowerCase()
  if (!term) return true
  return (
    order.reference.toLowerCase().includes(term) ||
    order.user_name.toLowerCase().includes(term) ||
    order.provider_name.toLowerCase().includes(term) ||
    order.description.toLowerCase().includes(term)
  )
}

export async function listOrders(query: OrderQuery): Promise<Paged<Order>> {
  if (!isSupabaseConfigured) {
    const filtered = demoOrders.filter((order) => matches(order, query))
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('orders')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.category !== 'all') builder = builder.eq('category', query.category)
  if (query.city !== 'all') builder = builder.eq('city', query.city)
  if (query.days !== 'all') builder = builder.gte('created_at', isoDaysAgo(query.days))

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,description.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Order[], total: count ?? 0 }
}

export async function getOrder(id: string): Promise<Order | null> {
  if (!isSupabaseConfigured) {
    return delay(demoOrders.find((order) => order.id === id) ?? null)
  }

  const { data, error } = await requireSupabase()
    .from('orders')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as Order | null) ?? null
}

export interface OrderDetail {
  offers: OrderOffer[]
  payments: Payment[]
}

export async function getOrderDetail(orderId: string): Promise<OrderDetail> {
  if (!isSupabaseConfigured) {
    const [offers, payments] = await Promise.all([
      delay(
        demoOffers.filter((offer) => offer.order_id === orderId).sort((a, b) => a.price - b.price),
      ),
      listPaymentsForOrder(orderId),
    ])
    return { offers, payments }
  }

  const [offers, payments] = await Promise.all([
    requireSupabase()
      .from('order_offers')
      .select('*')
      .eq('order_id', orderId)
      .order('price', { ascending: true }),
    listPaymentsForOrder(orderId),
  ])

  if (offers.error) throw offers.error
  return { offers: (offers.data ?? []) as OrderOffer[], payments }
}

/**
 * Accepts an offer on behalf of the customer.
 *
 * Three things move together: the offer wins and its rivals are rejected, the
 * order takes on the provider and the agreed price, and the balance is charged.
 * The payment is written last so a failure earlier leaves no orphan charge.
 */
export async function acceptOffer(order: Order, offer: OrderOffer): Promise<void> {
  const acceptedAt = new Date().toISOString()
  const platformShare = Math.round(offer.price * COMMISSION * 100) / 100

  if (!isSupabaseConfigured) {
    for (const candidate of demoOffers.filter((row) => row.order_id === order.id)) {
      candidate.status = candidate.id === offer.id ? 'accepted' : 'rejected'
    }
    const target = demoOrders.find((candidate) => candidate.id === order.id)
    if (target) {
      target.provider_id = offer.provider_id
      target.provider_name = offer.provider_name
      target.accepted_offer_id = offer.id
      target.final_price = offer.price
      target.platform_share = platformShare
      target.status = 'confirmed'
      target.accepted_at = acceptedAt
    }
    await delay(null, 380)
  } else {
    const client = requireSupabase()

    const rejected = await client
      .from('order_offers')
      .update({ status: 'rejected' })
      .eq('order_id', order.id)
      .neq('id', offer.id)
    if (rejected.error) throw rejected.error

    const accepted = await client
      .from('order_offers')
      .update({ status: 'accepted' })
      .eq('id', offer.id)
    if (accepted.error) throw accepted.error

    const updated = await client
      .from('orders')
      .update({
        provider_id: offer.provider_id,
        provider_name: offer.provider_name,
        accepted_offer_id: offer.id,
        final_price: offer.price,
        platform_share: platformShare,
        status: 'confirmed',
        accepted_at: acceptedAt,
      })
      .eq('id', order.id)
      // Only an order still open for offers can be confirmed, so two admins
      // accepting different offers at once cannot both win.
      .eq('status', 'new')
    if (updated.error) throw updated.error
  }

  await addPayment({
    user_id: order.user_id,
    user_name: order.user_name,
    provider_id: offer.provider_id,
    provider_name: offer.provider_name,
    order_id: order.id,
    order_reference: order.reference,
    kind: 'order',
    description: `${order.category} — رصيد الطلب`,
    amount: offer.price,
    platform_share: platformShare,
    net_amount: Math.round((offer.price - platformShare) * 100) / 100,
  })

  await recordAudit({
    action: 'order.accept_offer',
    entity: 'order',
    entityId: order.id,
    entityLabel: order.reference,
    details: { to: offer.provider_name, amount: offer.price },
  })
}

/** The stage that follows each one, or null where the order is finished. */
const NEXT_STATUS: Partial<Record<OrderStatus, OrderStatus>> = {
  confirmed: 'on_the_way',
  on_the_way: 'in_progress',
  in_progress: 'completed',
  completed: 'closed',
}

export const nextStatusOf = (status: OrderStatus): OrderStatus | null =>
  NEXT_STATUS[status] ?? null

export async function advanceOrder(order: Order, status: OrderStatus): Promise<void> {
  const previous = order.status
  const completedAt =
    status === 'completed' ? new Date().toISOString() : order.completed_at

  if (!isSupabaseConfigured) {
    const target = demoOrders.find((candidate) => candidate.id === order.id)
    if (target) {
      target.status = status
      target.completed_at = completedAt
    }
    await delay(null, 260)
  } else {
    const { error } = await requireSupabase()
      .from('orders')
      .update({ status, completed_at: completedAt })
      .eq('id', order.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'order.status',
    entity: 'order',
    entityId: order.id,
    entityLabel: order.reference,
    details: { from: ORDER_STATUS_LABEL[previous], to: ORDER_STATUS_LABEL[status] },
  })
}

export async function cancelOrder(order: Order, reason: string): Promise<void> {
  const previous = order.status
  const cancelledAt = new Date().toISOString()

  if (!isSupabaseConfigured) {
    const target = demoOrders.find((candidate) => candidate.id === order.id)
    if (target) {
      target.status = 'cancelled'
      target.cancelled_at = cancelledAt
      target.cancel_reason = reason
    }
    await delay(null, 320)
  } else {
    const { error } = await requireSupabase()
      .from('orders')
      .update({ status: 'cancelled', cancelled_at: cancelledAt, cancel_reason: reason })
      .eq('id', order.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'order.cancel',
    entity: 'order',
    entityId: order.id,
    entityLabel: order.reference,
    details: { from: ORDER_STATUS_LABEL[previous], to: ORDER_STATUS_LABEL.cancelled, reason },
  })
}

export const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  new: 'مفتوح للعروض',
  confirmed: 'مؤكد',
  on_the_way: 'في الطريق',
  in_progress: 'جارٍ التنفيذ',
  completed: 'منفّذ',
  closed: 'مغلق',
  cancelled: 'ملغي',
}

export const OFFER_STATUS_LABEL: Record<string, string> = {
  pending: 'بانتظار الرد',
  accepted: 'مقبول',
  rejected: 'مرفوض',
  withdrawn: 'مسحوب',
}

/** The stages an order walks through, in order, for the progress trail. */
export const ORDER_TRAIL: OrderStatus[] = [
  'new',
  'confirmed',
  'on_the_way',
  'in_progress',
  'completed',
  'closed',
]
