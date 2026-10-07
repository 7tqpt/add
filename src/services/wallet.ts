import { requireSupabase } from '@/lib/supabase'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

/**
 * «رصيد فرحتي» من جهة الإدارة — `supabase/wallet.sql`.
 *
 * اختار صاحبُ المنصّة: الاسترجاعُ المحسوبُ عند الإلغاء **ينتظر اعتمادَه** قبل
 * أن يدخل رصيدَ العميل، **ولا يُسحب إلّا إلى حسابٍ دفع منه العميل** — «عشن غسل
 * الامول». والرفضُ والمطابقةُ في القاعدة؛ وما هنا يعرض ويقرّر.
 */

export type WithdrawalStatus = 'pending' | 'paid' | 'rejected'
export type WithdrawalMethod = 'jawali' | 'kuraimi' | 'bank_transfer' | 'cash_wallet'

export interface Withdrawal {
  id: string
  reference: string
  /** عميلٌ يُرجَع إلى حسابٍ دفع منه، أو مقدّمُ خدمةٍ يُسحب إلى حسابه الموثَّق. */
  party: 'customer' | 'provider'
  amount: number
  method: WithdrawalMethod
  /** ما كتبه العميلُ في طلب السحب. */
  account: string
  status: WithdrawalStatus
  note: string
  created_at: string
  decided_at: string | null
  user_name: string | null
  user_phone: string | null
  /** الدفعةُ التي طابقها الرقم — كما في سجلّ الدفع. */
  paid_reference: string | null
  paid_account: string | null
  paid_method: string | null
  paid_booking: string | null
  matched: boolean
}

export interface PendingRefund {
  id: string
  reference: string
  amount: number
  description: string
  created_at: string
  booking_id: string | null
  booking_reference: string
  user_name: string
  provider_name: string
  paid_amount: number | null
  booking_status: string | null
}

/** حسابُ سحب مقدّم الخدمة — يكتبه، ولا يُسحب إليه حتى يُوثَّق هنا. */
export interface PayoutAccount {
  provider_id: string
  provider_name: string
  owner_name: string
  provider_phone: string
  method: WithdrawalMethod
  account: string
  holder_name: string
  status: 'pending' | 'verified' | 'rejected'
  note: string
  updated_at: string
}

export const WITHDRAWAL_METHOD_LABEL: Record<WithdrawalMethod, string> = {
  jawali: 'جوالي',
  kuraimi: 'الكريمي',
  bank_transfer: 'حساب بنكي',
  cash_wallet: 'محفظة نقدية',
}

export const WITHDRAWAL_STATUS_LABEL: Record<WithdrawalStatus, string> = {
  pending: 'بانتظار التحويل',
  paid: 'حُوِّل',
  rejected: 'مرفوض',
}

/**
 * الرقمُ موحَّداً للمطابقة — نسخةُ `wallet_norm` في `wallet.sql` حرفاً بحرف.
 *
 * «٧٧٧ ١٢٣ ٤٥٦» و«+967777123456» و«777123456» حسابٌ واحد. والقاعدةُ هي التي
 * تقرّر؛ وهذه للعرض في وضع التجربة ولتمييز الرقمين في الجدول.
 */
export function normalizeAccount(account: string | null | undefined): string {
  const latin = (account ?? '').replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x6f0))
  const digits = latin.replace(/\D/g, '')
  return digits.replace(/^(00)?967(?=\d{9}$)/, '')
}

const now = Date.now()
const ago = (hours: number) => new Date(now - hours * 3_600_000).toISOString()

const demoWithdrawals: Withdrawal[] = [
  {
    id: 'wd_7', reference: 'WD-2026-0007', party: 'customer', amount: 120000, method: 'jawali', account: '777 123 456',
    status: 'pending', note: '', created_at: ago(5), decided_at: null,
    user_name: 'بلقيس الحضرمي', user_phone: '+967777123456',
    paid_reference: 'PAY-2026-4C11AA', paid_account: '777 123 456', paid_method: 'jawali',
    paid_booking: 'BK-2026-000318', matched: true,
  },
  {
    id: 'wd_6', reference: 'WD-2026-0006', party: 'customer', amount: 255000, method: 'kuraimi', account: '3001234567',
    status: 'pending', note: '', created_at: ago(29), decided_at: null,
    user_name: 'أحمد الشرعي', user_phone: '+967771998210',
    paid_reference: 'PAY-2026-91E2B0', paid_account: '3001 234 567', paid_method: 'kuraimi',
    paid_booking: 'BK-2026-000270', matched: true,
  },
  {
    id: 'wd_5', reference: 'WD-2026-0005', party: 'customer', amount: 40000, method: 'jawali', account: '771 998 210',
    status: 'paid', note: '', created_at: ago(120), decided_at: ago(100),
    user_name: 'فاطمة الصنعاني', user_phone: '+967771998210',
    paid_reference: 'PAY-2026-0D77F3', paid_account: '771998210', paid_method: 'jawali',
    paid_booking: 'BK-2026-000244', matched: true,
  },
]

// طلبُ مقدّم خدمة: يُسحب إلى حسابه الموثَّق، فالمطابقةُ بحسابه لا بدفعة.
demoWithdrawals.unshift({
  id: 'wd_8', reference: 'WD-2026-0008', party: 'provider', amount: 300000, method: 'kuraimi',
  account: '3001234567', status: 'pending', note: '', created_at: ago(2), decided_at: null,
  user_name: 'مؤسسة الأصالة', user_phone: '+967770024275',
  paid_reference: 'حساب مسجَّل', paid_account: '3001234567', paid_method: 'kuraimi',
  paid_booking: null, matched: true,
})

const demoPayoutAccounts: PayoutAccount[] = [
  {
    provider_id: 'prv_9', provider_name: 'استوديو السعادة', owner_name: 'فهد بن شملان',
    provider_phone: '+967771234500', method: 'jawali', account: '771 234 500',
    holder_name: 'فهد عبدالله بن شملان', status: 'pending', note: '', updated_at: ago(7),
  },
]

const demoRefunds: PendingRefund[] = [
  {
    id: 'rfd_1', reference: 'RFD-2026-292BAD29', amount: 170000,
    description: 'استرداد إلغاء — القاعات والخيام', created_at: ago(3),
    booking_id: null, booking_reference: 'BK-2026-000331', user_name: 'مريم الحضرمي',
    provider_name: 'مركز التاج', paid_amount: 170000, booking_status: 'cancelled',
  },
  {
    id: 'rfd_2', reference: 'RFD-2026-8A01C3F2', amount: 45000,
    description: 'استرداد — اعتذر مقدّم الخدمة', created_at: ago(26),
    booking_id: null, booking_reference: 'BK-2026-000327', user_name: 'عبدالرحمن الأهدل',
    provider_name: 'استوديو السعادة', paid_amount: 45000, booking_status: 'rejected',
  },
]

export async function listWithdrawals(status: WithdrawalStatus | 'all' = 'all'): Promise<Withdrawal[]> {
  if (!isSupabaseConfigured) {
    // «مطابق» في وضع التجربة محسوبٌ كما تحسبه القاعدة، لا مكتوبٌ باليد.
    return delay(
      demoWithdrawals
        .filter((w) => status === 'all' || w.status === status)
        .map((w) => ({ ...w, matched: normalizeAccount(w.account) === normalizeAccount(w.paid_account) })),
    )
  }
  const { data, error } = await requireSupabase().rpc('api_admin_withdrawals', {
    p_status: status === 'all' ? null : status,
  })
  if (error) throw error
  return ((data as Withdrawal[] | null) ?? []).map((w) => ({ ...w, amount: Number(w.amount) }))
}

/**
 * «حوّلتُ المبلغ» أو «رفض».
 *
 * **والرفضُ بلا سببٍ لا يُرسل** — السببُ يصل العميلَ مع عودة المبلغ إلى رصيده،
 * ورفضٌ صامتٌ يجعله يظنّ أنّ مالَه ضاع. والقاعدةُ تردّه كذلك.
 */
export async function decideWithdrawal(withdrawal: Withdrawal, paid: boolean, note = ''): Promise<void> {
  if (!paid && !note.trim()) throw new Error('اكتب سبب الرفض — يصل العميل')
  if (!isSupabaseConfigured) {
    const target = demoWithdrawals.find((w) => w.id === withdrawal.id)
    if (!target || target.status !== 'pending') throw new Error('قُرّر هذا الطلبُ من قبل')
    target.status = paid ? 'paid' : 'rejected'
    target.note = note.trim()
    target.decided_at = new Date().toISOString()
    await delay(null, 380)
  } else {
    const { error } = await requireSupabase().rpc('api_admin_decide_withdrawal', {
      p_id: withdrawal.id,
      p_paid: paid,
      p_note: note.trim(),
    })
    if (error) throw error
  }
  await recordAudit({
    action: paid ? 'withdrawal.paid' : 'withdrawal.reject',
    entity: 'withdrawal',
    entityId: withdrawal.id,
    entityLabel: withdrawal.reference,
    details: { amount: withdrawal.amount, account: withdrawal.account, note: note.trim() },
  })
}

export async function listPendingRefunds(): Promise<PendingRefund[]> {
  if (!isSupabaseConfigured) return delay(demoRefunds.map((r) => ({ ...r })))
  const { data, error } = await requireSupabase().rpc('api_admin_pending_refunds')
  if (error) throw error
  return ((data as PendingRefund[] | null) ?? []).map((r) => ({ ...r, amount: Number(r.amount) }))
}

/**
 * اعتمادُ الاسترجاع المحسوب — كاملاً أو أقلّ — أو رفضُه.
 *
 * والمبلغُ لا يزيد على ما حسبه سلّمُ الإلغاء: ذاك سقف. والرفضُ يُعيده مستحقّاً
 * لمقدّم الخدمة في الحجز، فسببُه يصل العميلَ ولا يُترك فارغاً.
 */
export async function decideRefund(
  refund: PendingRefund,
  approve: boolean,
  amount: number | null = null,
  note = '',
): Promise<void> {
  if (approve && amount !== null && (amount <= 0 || amount > refund.amount)) {
    throw new Error(`المبلغ بين ريالٍ و${refund.amount.toLocaleString('en-US')} ريال`)
  }
  if (!approve && !note.trim()) throw new Error('اكتب سبب الرفض — يصل العميل')
  if (!isSupabaseConfigured) {
    const index = demoRefunds.findIndex((r) => r.id === refund.id)
    if (index < 0) throw new Error('قُرّر هذا الاسترجاعُ من قبل')
    demoRefunds.splice(index, 1)
    await delay(null, 380)
  } else {
    const { error } = await requireSupabase().rpc('api_admin_decide_refund', {
      p_payment_id: refund.id,
      p_approve: approve,
      p_amount: amount,
      p_note: note.trim(),
    })
    if (error) throw error
  }
  await recordAudit({
    action: approve ? 'refund.credit' : 'refund.decline',
    entity: 'payment',
    entityId: refund.id,
    entityLabel: refund.reference,
    details: { amount: amount ?? refund.amount, booking: refund.booking_reference, note: note.trim() },
  })
}

export async function listPayoutAccounts(): Promise<PayoutAccount[]> {
  if (!isSupabaseConfigured) return delay(demoPayoutAccounts.filter((a) => a.status === 'pending').map((a) => ({ ...a })))
  const { data, error } = await requireSupabase().rpc('api_admin_payout_accounts', { p_status: 'pending' })
  if (error) throw error
  return (data as PayoutAccount[] | null) ?? []
}

/**
 * توثيقُ حساب سحب المزوّد أو رفضُه — **وبلا سببٍ لا رفض**: يصل المزوّدَ ليصحّح.
 */
export async function verifyPayoutAccount(account: PayoutAccount, approve: boolean, note = ''): Promise<void> {
  if (!approve && !note.trim()) throw new Error('اكتب سبب الرفض — يصل مقدّم الخدمة')
  if (!isSupabaseConfigured) {
    const target = demoPayoutAccounts.find((a) => a.provider_id === account.provider_id)
    if (!target || target.status !== 'pending') throw new Error('لا حسابَ ينتظر التوثيق لهذا المزوّد')
    target.status = approve ? 'verified' : 'rejected'
    target.note = note.trim()
    await delay(null, 380)
  } else {
    const { error } = await requireSupabase().rpc('api_admin_verify_payout_account', {
      p_provider_id: account.provider_id,
      p_approve: approve,
      p_note: note.trim(),
    })
    if (error) throw error
  }
  await recordAudit({
    action: approve ? 'payout_account.verify' : 'payout_account.reject',
    entity: 'provider',
    entityId: account.provider_id,
    entityLabel: account.provider_name,
    details: { method: account.method, account: account.account, holder: account.holder_name, note: note.trim() },
  })
}
