import { requireSupabase } from '@/lib/supabase'
import type {
  Dispute,
  DisputeCategory,
  DisputeMessage,
  DisputeStatus,
  Paged,
  Review,
  ReviewStatus,
} from '@/lib/types'
import { mockDisputeMessages, mockDisputes, mockReviews } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoReviews: Review[] = [...mockReviews].sort(
  (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
)
const demoDisputes: Dispute[] = [...mockDisputes].sort(
  (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
)
const demoMessages: DisputeMessage[] = [...mockDisputeMessages]

// ---------------------------------------------------------------------------
// التقييمات
// ---------------------------------------------------------------------------

export interface ReviewQuery {
  search: string
  status: ReviewStatus | 'all'
  rating: number | 'all'
  page: number
  pageSize: number
}

export async function listReviews(query: ReviewQuery): Promise<Paged<Review>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoReviews.filter((review) => {
      if (query.status !== 'all' && review.status !== query.status) return false
      if (query.rating !== 'all' && review.rating !== query.rating) return false
      if (!term) return true
      return (
        review.user_name.toLowerCase().includes(term) ||
        review.provider_name.toLowerCase().includes(term) ||
        review.comment.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    .from('v_admin_reviews')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.rating !== 'all') builder = builder.eq('rating', query.rating)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,comment.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Review[], total: count ?? 0 }
}

/** Published reviews for one provider, newest first — for the provider screen. */
export async function listProviderReviews(providerId: string, limit = 20): Promise<Review[]> {
  if (!isSupabaseConfigured) {
    return delay(
      demoReviews.filter((review) => review.provider_id === providerId).slice(0, limit),
    )
  }

  const { data, error } = await requireSupabase()
    .from('v_admin_reviews')
    .select('*')
    .eq('provider_id', providerId)
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as Review[]
}

/**
 * Hiding a review does not delete it: the provider's rating is recomputed from
 * published rows only, but the original text stays for the audit trail.
 */
export async function setReviewStatus(
  review: Review,
  status: ReviewStatus,
  reason = '',
): Promise<void> {
  const previous = review.status
  const patch = { status, hidden_reason: status === 'hidden' ? reason : '' }

  if (!isSupabaseConfigured) {
    const target = demoReviews.find((candidate) => candidate.id === review.id)
    if (target) Object.assign(target, patch)
    await delay(null, 240)
  } else {
    const { error } = await requireSupabase().from('reviews').update(patch).eq('id', review.id)
    if (error) throw error
  }

  await recordAudit({
    action: `review.${status}`,
    entity: 'review',
    entityId: review.id,
    entityLabel: `تقييم ${review.provider_name} من ${review.user_name}`,
    details: {
      from: REVIEW_STATUS_LABEL[previous],
      to: REVIEW_STATUS_LABEL[status],
      ...(reason ? { reason } : {}),
    },
  })
}

export const REVIEW_STATUS_LABEL: Record<ReviewStatus, string> = {
  published: 'منشور',
  hidden: 'مخفي',
  flagged: 'مُبلَّغ عنه',
}

// ---------------------------------------------------------------------------
// النزاعات
// ---------------------------------------------------------------------------

export interface DisputeQuery {
  search: string
  status: DisputeStatus | 'all'
  category: DisputeCategory | 'all'
  page: number
  pageSize: number
}

export async function listDisputes(query: DisputeQuery): Promise<Paged<Dispute>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoDisputes.filter((dispute) => {
      if (query.status !== 'all' && dispute.status !== query.status) return false
      if (query.category !== 'all' && dispute.category !== query.category) return false
      if (!term) return true
      return (
        dispute.reference.toLowerCase().includes(term) ||
        dispute.subject.toLowerCase().includes(term) ||
        dispute.user_name.toLowerCase().includes(term) ||
        dispute.provider_name.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    .from('disputes')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.category !== 'all') builder = builder.eq('category', query.category)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,subject.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Dispute[], total: count ?? 0 }
}

export async function getDispute(id: string): Promise<Dispute | null> {
  if (!isSupabaseConfigured) return delay(demoDisputes.find((d) => d.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('disputes')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as Dispute | null) ?? null
}

export async function listDisputeMessages(disputeId: string): Promise<DisputeMessage[]> {
  if (!isSupabaseConfigured) {
    return delay(
      demoMessages
        .filter((message) => message.dispute_id === disputeId)
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()),
    )
  }

  const { data, error } = await requireSupabase()
    .from('dispute_messages')
    .select('*')
    .eq('dispute_id', disputeId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as DisputeMessage[]
}

export async function replyToDispute(
  dispute: Dispute,
  body: string,
  authorName: string,
): Promise<DisputeMessage> {
  const message: DisputeMessage = {
    id: `dmsg_${Date.now().toString(36)}`,
    dispute_id: dispute.id,
    author: 'admin',
    author_name: authorName,
    body,
    created_at: new Date().toISOString(),
  }

  if (!isSupabaseConfigured) {
    demoMessages.push(message)
    await delay(null, 320)
  } else {
    const { data, error } = await requireSupabase()
      .from('dispute_messages')
      .insert({ dispute_id: dispute.id, author: 'admin', author_name: authorName, body })
      .select()
      .single()
    if (error) throw error
    return data as DisputeMessage
  }

  await recordAudit({
    action: 'dispute.reply',
    entity: 'dispute',
    entityId: dispute.id,
    entityLabel: dispute.reference,
    details: { subject: dispute.subject },
  })

  return message
}

/**
 * Closing a dispute can order money back to the customer. The figure is
 * recorded on the dispute; the actual refund is issued from the payment row so
 * there is one place where money moves.
 */
export async function resolveDispute(
  dispute: Dispute,
  status: DisputeStatus,
  resolution: string,
  refundAmount: number,
  resolvedBy: string,
): Promise<void> {
  const previous = dispute.status
  const settled = status === 'resolved' || status === 'closed'
  const patch = {
    status,
    resolution: settled ? resolution : dispute.resolution,
    refund_amount: settled ? refundAmount : dispute.refund_amount,
    resolved_by: settled ? resolvedBy : '',
    resolved_at: settled ? new Date().toISOString() : null,
  }

  if (!isSupabaseConfigured) {
    const target = demoDisputes.find((candidate) => candidate.id === dispute.id)
    if (target) Object.assign(target, patch)
    await delay(null, 320)
  } else {
    const { error } = await requireSupabase().from('disputes').update(patch).eq('id', dispute.id)
    if (error) throw error
  }

  await recordAudit({
    action: `dispute.${status}`,
    entity: 'dispute',
    entityId: dispute.id,
    entityLabel: dispute.reference,
    details: {
      from: DISPUTE_STATUS_LABEL[previous],
      to: DISPUTE_STATUS_LABEL[status],
      ...(settled && refundAmount ? { amount: refundAmount } : {}),
      ...(settled && resolution ? { resolution } : {}),
    },
  })
}

export const DISPUTE_STATUS_LABEL: Record<DisputeStatus, string> = {
  open: 'مفتوح',
  investigating: 'قيد التحقيق',
  resolved: 'محسوم',
  closed: 'مغلق',
}

export const DISPUTE_CATEGORY_LABEL: Record<DisputeCategory, string> = {
  no_show: 'عدم الحضور',
  quality: 'جودة الخدمة',
  payment: 'مشكلة دفع',
  cancellation: 'خلاف على الإلغاء',
  behaviour: 'سلوك غير لائق',
  other: 'أخرى',
}

export const DISPUTE_PARTY_LABEL: Record<'customer' | 'provider' | 'admin', string> = {
  customer: 'العميل',
  provider: 'مقدّم الخدمة',
  admin: 'الإدارة',
}
