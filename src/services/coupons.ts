import { requireSupabase } from '@/lib/supabase'
import type { Tone } from '@/components/ui/Badge'
import type { Coupon, CouponKind } from '@/lib/types'
import { mockCoupons } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoCoupons: Coupon[] = [...mockCoupons]

export const COUPON_KIND_LABEL: Record<CouponKind, string> = {
  percent: 'نسبة مئوية',
  fixed: 'مبلغ ثابت',
}

/**
 * الحالةُ كما تُقرأ لا كما تُخزَّن.
 *
 * والفرقُ بين «موقوف» و«منتهٍ» و«نفد» يهمّ من يفتح الصفحة: الأوّل قرارُه هو،
 * والثاني مضى وقتُه، والثالث نجح حتى نفد. وثلاثتُها في القاعدة `is_live=false`
 * — فلو عُرضت جملةً واحدةً لَما عرف لماذا كودُه لا يعمل.
 */
export function couponState(coupon: Coupon): { label: string; tone: Tone } {
  if (!coupon.is_active) return { label: 'موقوف', tone: 'critical' }
  const now = Date.now()
  if (new Date(coupon.starts_at).getTime() > now) {
    return { label: 'لم يبدأ', tone: 'warning' }
  }
  if (coupon.ends_at && new Date(coupon.ends_at).getTime() < now) {
    return { label: 'انتهى', tone: 'neutral' }
  }
  if (coupon.max_uses > 0 && coupon.used_count >= coupon.max_uses) {
    return { label: 'نفد', tone: 'neutral' }
  }
  return { label: 'سارٍ', tone: 'good' }
}

export async function listCoupons(): Promise<Coupon[]> {
  if (!isSupabaseConfigured) return delay([...demoCoupons])

  const { data, error } = await requireSupabase()
    .from('v_coupons')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as Coupon[]
}

export interface NewCoupon {
  code: string
  description: string
  kind: CouponKind
  value: number
  max_discount: number
  min_total: number
  category_id: string | null
  starts_at: string
  ends_at: string | null
  max_uses: number
  max_uses_per_user: number
}

export async function createCoupon(input: NewCoupon): Promise<void> {
  // الكودُ بحروفٍ كبيرة هنا أيضاً لا في القاعدة وحدها: لو كُتب صغيراً في
  // اللوحة لَما طابق ما تبحث عنه الدالّة، فيكون كوداً لا يعمل ولا يُعرف لماذا.
  const row = { ...input, code: input.code.trim().toUpperCase() }

  if (!isSupabaseConfigured) {
    demoCoupons.unshift({
      ...row,
      id: `cp_${Date.now()}`,
      category_name: null,
      used_count: 0,
      is_active: true,
      is_live: true,
      redemptions: 0,
      total_discount: 0,
      created_at: new Date().toISOString(),
    })
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase().from('coupons').insert(row)
    if (error) throw error
  }

  await recordAudit({
    action: 'coupon.create',
    entity: 'coupon',
    entityId: row.code,
    entityLabel: row.code,
    details: {
      النوع: COUPON_KIND_LABEL[row.kind],
      القيمة: row.value,
      'الحد الأقصى للاستعمالات': row.max_uses || 'بلا حدّ',
    },
  })
}

export async function setCouponActive(coupon: Coupon, is_active: boolean): Promise<void> {
  if (!isSupabaseConfigured) {
    const target = demoCoupons.find((candidate) => candidate.id === coupon.id)
    if (target) {
      target.is_active = is_active
      target.is_live = is_active && couponState({ ...target, is_active }).label === 'سارٍ'
    }
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('coupons')
      .update({ is_active })
      .eq('id', coupon.id)
    if (error) throw error
  }

  await recordAudit({
    action: is_active ? 'coupon.activate' : 'coupon.deactivate',
    entity: 'coupon',
    entityId: coupon.id,
    entityLabel: coupon.code,
    details: {
      من: coupon.is_active ? 'يعمل' : 'موقوف',
      إلى: is_active ? 'يعمل' : 'موقوف',
      'ما صُرف عليه': coupon.total_discount,
    },
  })
}
