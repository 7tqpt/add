import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  Payment,
  PaymentKind,
  PaymentMethod,
  PaymentStatus,
  PaymentTotals,
  Settlement,
  SettlementStatus,
} from '@/lib/types'
import { mockPayments, mockSettlements } from '@/data/mock'
import { delay, isSupabaseConfigured, isoDaysAgo } from './base'
import { recordAudit } from './audit'

const demoPayments: Payment[] = [...mockPayments]
const demoSettlements: Settlement[] = [...mockSettlements]

// ---------------------------------------------------------------------------
// المدفوعات
// ---------------------------------------------------------------------------

export interface PaymentQuery {
  search: string
  status: PaymentStatus | 'all'
  method: PaymentMethod | 'all'
  kind: PaymentKind | 'all'
  days: number | 'all'
  page: number
  pageSize: number
}

function matches(payment: Payment, query: Omit<PaymentQuery, 'page' | 'pageSize'>): boolean {
  if (query.status !== 'all' && payment.status !== query.status) return false
  if (query.method !== 'all' && payment.method !== query.method) return false
  if (query.kind !== 'all' && payment.kind !== query.kind) return false
  if (query.days !== 'all' && payment.created_at < isoDaysAgo(query.days)) return false

  const term = query.search.trim().toLowerCase()
  if (!term) return true
  return (
    payment.reference.toLowerCase().includes(term) ||
    payment.user_name.toLowerCase().includes(term) ||
    payment.provider_name.toLowerCase().includes(term) ||
    payment.booking_reference.toLowerCase().includes(term)
  )
}

export async function listPayments(query: PaymentQuery): Promise<Paged<Payment>> {
  if (!isSupabaseConfigured) {
    const filtered = demoPayments.filter((payment) => matches(payment, query))
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
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
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,booking_reference.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Payment[], total: count ?? 0 }
}

function summarise(payments: Payment[]): PaymentTotals {
  const settled = payments.filter((p) => p.status === 'paid')
  const refunded = payments.filter((p) => p.status === 'refunded')
  // A pending payment has not resolved either way, so it is excluded from the
  // success rate rather than counted as a failure.
  const resolved = payments.filter((p) => p.status !== 'pending')

  const byMethod = new Map<PaymentMethod, number>()
  for (const payment of settled) {
    byMethod.set(payment.method, (byMethod.get(payment.method) ?? 0) + payment.amount)
  }

  return {
    collected: settled.reduce((sum, p) => sum + p.amount, 0),
    platformShare: settled.reduce((sum, p) => sum + p.platform_share, 0),
    refunded: refunded.reduce((sum, p) => sum + p.amount, 0),
    refundedCount: refunded.length,
    successRate: resolved.length === 0 ? 0 : settled.length / resolved.length,
    byMethod: [...byMethod]
      .map(([method, amount]) => ({ method, amount }))
      .sort((a, b) => b.amount - a.amount),
  }
}

/** Totals over every matching row, not the page on screen. */
export async function getPaymentTotals(
  query: Omit<PaymentQuery, 'page' | 'pageSize'>,
): Promise<PaymentTotals> {
  if (!isSupabaseConfigured) {
    return delay(summarise(demoPayments.filter((payment) => matches(payment, query))))
  }

  let builder = requireSupabase().from('payments').select('amount, platform_share, method, status')

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.method !== 'all') builder = builder.eq('method', query.method)
  if (query.kind !== 'all') builder = builder.eq('kind', query.kind)
  if (query.days !== 'all') builder = builder.gte('created_at', isoDaysAgo(query.days))
  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%,booking_reference.ilike.%${safe}%`,
    )
  }

  const { data, error } = await builder
  if (error) throw error
  return summarise((data ?? []) as Payment[])
}

/**
 * تأكيدُ حوالةٍ أبلغ بها العميل من التطبيق.
 *
 * **بدالّة لا بتحديثٍ مباشر:** `api_admin_confirm_payment` تزيد المدفوع في
 * الحجز وتُشعر الطرفين — وتحديثُ الصفّ هنا يترك الحجزَ يقول «لم يُدفع» وقد
 * دُفع، ويترك العميل بلا خبر.
 */
export async function confirmPayment(payment: Payment, gatewayRef = ''): Promise<void> {
  if (!isSupabaseConfigured) {
    const target = demoPayments.find((candidate) => candidate.id === payment.id)
    if (target) target.status = 'paid'
    await delay(null, 380)
  } else {
    const { error } = await requireSupabase().rpc('api_admin_confirm_payment', {
      p_payment_id: payment.id,
      p_gateway_ref: gatewayRef,
    })
    if (error) throw error
  }

  await recordAudit({
    action: 'payment.confirm',
    entity: 'payment',
    entityId: payment.id,
    entityLabel: payment.reference,
    details: { amount: payment.amount, user: payment.user_name },
  })
}

/**
 * ردُّ إبلاغٍ لم نجد حوالته.
 *
 * تُعلَّم `failed` ولا تُحذف: العميل يجب أن يرى أن إبلاغه رُدّ ولماذا، لا أن
 * يختفي بلا أثرٍ فيظنّ أن المنصّة أخذت ماله.
 */
export async function rejectPayment(payment: Payment, reason = ''): Promise<void> {
  if (!isSupabaseConfigured) {
    const target = demoPayments.find((candidate) => candidate.id === payment.id)
    if (target) target.status = 'failed'
    await delay(null, 380)
  } else {
    const { error } = await requireSupabase().rpc('api_admin_reject_payment', {
      p_payment_id: payment.id,
      p_reason: reason,
    })
    if (error) throw error
  }

  await recordAudit({
    action: 'payment.reject',
    entity: 'payment',
    entityId: payment.id,
    entityLabel: payment.reference,
    details: { amount: payment.amount, reason },
  })
}

/** حالُ مستحقّ المزوّد عن حجزِ هذه الدفعة. */
export type RefundSettlementState = 'none' | 'pending' | 'paid'

export interface RefundOutlook {
  refundable: boolean
  amount: number
  settlement: RefundSettlementState
}

/**
 * ما يصير لو رُدَّ هذا المبلغ — **يُسأل قبل الضغط لا بعده.**
 *
 * ومن علم بعد أن وقع الفعلُ لم يُنبَّه، أُخبر.
 */
export async function refundOutlook(payment: Payment): Promise<RefundOutlook> {
  if (!isSupabaseConfigured) {
    // **و«دُفع» تُرجَّح على غيرها.** لو كان للمزوّد تسويتان — واحدةٌ مدفوعةٌ
    // وأخرى معلّقة — فالخبرُ الذي يهمّ هو أنّ المال خرج.
    const mine = demoSettlements.filter((s) => s.provider_id === payment.provider_id)
    const item = mine.find((s) => s.status === 'paid') ?? mine[0]
    return delay({
      refundable: payment.status === 'paid',
      amount: payment.amount,
      settlement: (!item ? 'none' : item.status === 'paid' ? 'paid' : 'pending') as
        RefundSettlementState,
    })
  }

  const { data, error } = await requireSupabase().rpc('api_refund_outlook', {
    p_payment_id: payment.id,
  })
  if (error) throw error
  return data as RefundOutlook
}

/**
 * ردُّ المبلغ للعميل.
 *
 * **بدالّة لا بتحديثٍ مباشر — وكان تحديثاً مباشراً.** تُعلَّم الدفعةُ
 * `refunded` والحجزُ لا يعلم: `refunded_amount` يبقى صفراً. و`settlements.sql`
 * يحسب مستحقَّ المزوّد من **الحجز**:
 *
 *     sum(b.paid_amount - b.refunded_amount) as gross
 *
 * فمن ردَّ لعميلٍ ٥٠٠٬٠٠٠ ريالٍ من هنا، دفعت منصّتُه للمزوّد بعدها ٤٥٠٬٠٠٠
 * كأنّ الردَّ لم يكن — بلا أثرٍ ولا تنبيه. وهي علّةُ `confirmPayment` نفسُها
 * التي كُتبت فوقها منذ زمن، في وجهها الآخر.
 */
export async function refundPayment(payment: Payment): Promise<void> {
  const refunded_at = new Date().toISOString()

  if (!isSupabaseConfigured) {
    const target = demoPayments.find((candidate) => candidate.id === payment.id)
    if (target) {
      target.status = 'refunded'
      target.refunded_at = refunded_at
    }
    await delay(null, 380)
  } else {
    // والقيدُ في الحجز والدفعة معاً داخلَ الدالّة، فلا يقع أحدُهما دونه.
    const { error } = await requireSupabase().rpc('api_admin_refund_payment', {
      p_payment_id: payment.id,
      p_reason: '',
    })
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
  jawali: 'جوالي',
  cash_wallet: 'كاش المحفظة',
  kuraimi: 'الكريمي',
  bank_transfer: 'تحويل بنكي',
  card: 'بطاقة',
  wallet: 'محفظة التطبيق',
}

export const PAYMENT_KIND_LABEL: Record<PaymentKind, string> = {
  deposit: 'عربون',
  balance: 'سداد المتبقي',
  full: 'سداد كامل',
  subscription: 'اشتراك',
  promotion: 'باقة ترويجية',
  refund: 'استرداد',
}

// ---------------------------------------------------------------------------
// تسوية مستحقات الشركاء
// ---------------------------------------------------------------------------

export interface SettlementQuery {
  search: string
  status: SettlementStatus | 'all'
  page: number
  pageSize: number
}

export async function listSettlements(query: SettlementQuery): Promise<Paged<Settlement>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoSettlements.filter((settlement) => {
      if (query.status !== 'all' && settlement.status !== query.status) return false
      if (!term) return true
      return (
        settlement.reference.toLowerCase().includes(term) ||
        settlement.provider_name.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('v_admin_settlements')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`reference.ilike.%${safe}%,provider_name.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as Settlement[], total: count ?? 0 }
}

export async function setSettlementStatus(
  settlement: Settlement,
  status: SettlementStatus,
): Promise<void> {
  const previous = settlement.status
  const paid_at = status === 'paid' ? new Date().toISOString() : settlement.paid_at

  if (!isSupabaseConfigured) {
    const target = demoSettlements.find((candidate) => candidate.id === settlement.id)
    if (target) Object.assign(target, { status, paid_at })
    await delay(null, 280)
  } else {
    const { error } = await requireSupabase()
      .from('settlements').update({ status, paid_at }).eq('id', settlement.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'settlement.status',
    entity: 'settlement',
    entityId: settlement.id,
    entityLabel: `${settlement.reference} — ${settlement.provider_name}`,
    details: {
      from: SETTLEMENT_STATUS_LABEL[previous],
      to: SETTLEMENT_STATUS_LABEL[status],
      amount: settlement.net_amount,
    },
  })
}


/**
 * يحتسب تسويات شهرٍ ماضٍ من الحجوزات المنفَّذة المقبوضة.
 *
 * **والشهر السابق لا فترةٌ يكتبها المستخدم:** حقلا تاريخٍ يفتحان باب فتراتٍ
 * متداخلة، وحجزٌ في التداخل يُحتسب مرّتين — والقاعدة تمنع ازدواجه بفهرس، لكن
 * الأسهل ألّا يُطلب أصلاً. ومن أراد فترةً أخرى ناداها من محرّر SQL.
 *
 * يُعيد عدد التسويات التي أُنشئت.
 */
export async function buildLastMonthSettlements(): Promise<number> {
  const now = new Date()
  const from = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  const to = new Date(now.getFullYear(), now.getMonth(), 0)
  const iso = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

  if (!isSupabaseConfigured) {
    await delay(null, 420)
    return 0
  }

  const { data, error } = await requireSupabase().rpc('api_admin_build_settlements', {
    p_from: iso(from),
    p_to: iso(to),
  })
  if (error) {
    if (error.code === 'PGRST202') {
      throw new Error(
        'الدالة api_admin_build_settlements غير موجودة في قاعدتك — شغّل ' +
          'supabase/settlements.sql في محرّر SQL ثم أعد تحميل الصفحة.',
      )
    }
    throw error
  }

  const made = (data as number) ?? 0
  await recordAudit({
    action: 'settlement.build',
    entity: 'settlement',
    entityId: '',
    entityLabel: `${iso(from)} — ${iso(to)}`,
    details: { created: made },
  })
  return made
}

export const SETTLEMENT_STATUS_LABEL: Record<SettlementStatus, string> = {
  pending: 'بانتظار المراجعة',
  approved: 'معتمدة',
  paid: 'مدفوعة',
  on_hold: 'موقوفة',
}
