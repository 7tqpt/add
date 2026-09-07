import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  Promotion,
  ServiceProvider,
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
    .from('v_admin_subscription_plans')
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
    .from('v_admin_promotions')
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

// ---------------------------------------------------------------------------
// اللافتات الإعلانية — مساحة أعلى الرئيسية
// ---------------------------------------------------------------------------

/** الحاوية عامّة، فلا توقيعَ ينتهي ولا نداءَ شبكة لكل لافتة في التطبيق. */
const BANNER_BUCKET = 'ad-banners'

export interface NewBanner {
  /** صورةٌ أو أكثر. كلٌّ منها شريحةٌ تُمرَّر في التطبيق، وكلُّها لحملةٍ واحدة. */
  files: File[]
  starts_at: string
  ends_at: string
  /** كلمات الإعلان — تُكتب فوق الصور كلِّها. تُترك فارغةً فلا يُكتب شيء. */
  headline?: string
  /**
   * اسم المعلِن حين لا يكون مزوّداً مسجَّلاً — محلٌّ خارج المنصّة اشترى مساحة.
   *
   * **ويُتجاهل إن اختير مزوّد:** اسمه يتبدّل في مكانٍ واحد فتتبعه لافتاته،
   * ونصٌّ يُنسخ هنا يعتّق عند أوّل تغيير.
   */
  advertiser?: string
  /** المزوّد الذي تُفتح صفحته بالضغط. يُترك فارغاً فلا تُضغط اللافتة. */
  provider_id?: string
  amount?: number
}

/** أقصى ما يُقبل في حملةٍ واحدة — والدالّة في القاعدة تعيد ثماني شرائح. */
export const MAX_BANNER_IMAGES = 6

/**
 * يرفع صورَ اللافتة ثمّ يكتب صفّها.
 *
 * **وصفٌّ واحدٌ لِما كثُرت صورُه:** الحملةُ بثلاث صورٍ صفٌّ واحد بمصفوفةٍ من
 * ثلاثة روابط، لا ثلاثةُ صفوف. فمدّتُها ووجهتُها وكلماتُها واحدة، ولو كانت
 * صفوفاً لَوجب تعديلُ ثلاثةٍ كلَّما تبدّل تاريخُ الانتهاء — ولَظهرت في
 * القائمة ثلاثَ حملاتٍ لصاحبٍ اشترى واحدة. والتطبيقُ يفرشها شرائحَ عند
 * القراءة.
 *
 * **والصورة أوّلاً والصفّ بعدها:** لو كُتب الصفّ أوّلاً ثمّ فشل الرفع لظهرت
 * في التطبيق لافتةٌ بلا صورة — مستطيلٌ رماديٌّ بعرض الشاشة في أعلى الرئيسية.
 *
 * **واسم الملفّ يحمل ختم الوقت:** الحاوية عامّة والروابط تُخزَّن في ذاكرة
 * المتصفّح والوسطاء، فاسمٌ يتكرّر يعني لافتةً قديمةً تبقى معروضةً أياماً.
 *
 * **والحالة تُحسب لا تُسأل:** حملةٌ تبدأ اليوم تُكتب `active` فتظهر فوراً،
 * وما بدايتُه غداً يُكتب `scheduled` ويرفعه `expire_promotions` في موعده.
 */
export async function createBanner(banner: NewBanner): Promise<void> {
  const startsAt = new Date(banner.starts_at)
  const endsAt = new Date(banner.ends_at)
  if (!(endsAt > startsAt)) throw new Error('نهاية الحملة يجب أن تكون بعد بدايتها.')
  if (banner.files.length < 1) throw new Error('اللافتة تحتاج صورةً واحدةً على الأقل.')
  if (banner.files.length > MAX_BANNER_IMAGES) {
    throw new Error(`أقصى عددٍ للصور في الحملة الواحدة ${MAX_BANNER_IMAGES}.`)
  }

  const status: PromotionStatus = startsAt <= new Date() ? 'active' : 'scheduled'

  if (!isSupabaseConfigured) {
    demoPromotions.unshift({
      id: `banner-${Date.now()}`,
      provider_id: banner.provider_id ?? '',
      provider_name: '',
      kind: 'banner',
      placement: 'home',
      category_name: '',
      amount: banner.amount ?? 0,
      status,
      impressions: 0,
      clicks: 0,
      starts_at: startsAt.toISOString(),
      ends_at: endsAt.toISOString(),
    })
    await delay(null, 200)
    return
  }

  const client = requireSupabase()
  const stamp = Date.now()
  const paths: string[] = []

  // **وكلُّ ما رُفع يُنظَّف إن تعثّر شيءٌ بعده** — لا ما فشل وحدَه. صورةٌ
  // ثالثةٌ تسقط بعد نجاح اثنتين تترك ملفّين يتيمين في الحاوية لا صفَّ لهما،
  // ولا شيءَ في اللوحة يدلّ عليهما بعد ذلك.
  const sweep = () =>
    paths.length
      ? client.storage.from(BANNER_BUCKET).remove(paths).catch(() => undefined)
      : Promise.resolve()

  const image_urls: string[] = []
  for (const [index, file] of banner.files.entries()) {
    const extension = file.name.split('.').pop()?.toLowerCase() || 'jpg'
    const path = `home/${stamp}-${index + 1}.${extension}`

    const { error: uploadError } = await client.storage
      .from(BANNER_BUCKET)
      .upload(path, file, { contentType: file.type })
    if (uploadError) {
      await sweep()
      throw uploadError
    }

    paths.push(path)
    image_urls.push(client.storage.from(BANNER_BUCKET).getPublicUrl(path).data.publicUrl)
  }

  const { error } = await client.from('promotions').insert({
    kind: 'banner',
    placement: 'home',
    // والعمودُ القديم يُملأ بالأولى كذلك: تقاريرُ وشاشاتٌ تقرأ `image_url`
    // وحدَه، ولا يجوز أن تراها فارغةً لأنّ الصور صارت مصفوفة.
    image_url: image_urls[0],
    image_urls,
    headline: banner.headline?.trim() || '',
    advertiser: banner.provider_id ? '' : (banner.advertiser?.trim() || ''),
    provider_id: banner.provider_id || null,
    amount: banner.amount ?? 0,
    status,
    starts_at: startsAt.toISOString(),
    ends_at: endsAt.toISOString(),
  })
  if (error) {
    // الصفّ لم يُكتب، فالصورُ ملفّاتٌ يتيمةٌ في الحاوية: تُحذف ولا تُترك.
    await sweep()
    throw error
  }

  await recordAudit({
    action: 'promotion.banner',
    entity: 'promotion',
    entityId: paths[0],
    entityLabel: 'لافتة إعلانية — الرئيسية',
    details: {
      from: startsAt.toISOString().slice(0, 10),
      to: endsAt.toISOString().slice(0, 10),
      images: paths.length,
      ...(banner.headline?.trim() ? { headline: banner.headline.trim() } : {}),
      ...(banner.amount ? { amount: banner.amount } : {}),
    },
  })
}

/**
 * يضع مزوّداً في شريط «مزوّدون مميّزون» **من اللوحة مباشرة**.
 *
 * **والمسار الأصلي غيرُ هذا:** المزوّد يطلب من تطبيقه (`api_request_promotion`)
 * فتُنشأ دفعةٌ معلّقة وإعلانٌ `scheduled`، ثمّ يُفعَّل حين تُؤكَّد حوالته. وذاك
 * هو البيع.
 *
 * وهذا وضعٌ يدويّ لِما لا حوالةَ فيه: تعويضٌ عن عطل، أو اتّفاقٌ خارج النظام،
 * أو حملةٌ تفتحها المنصّة لمزوّدٍ تختاره. **ولذلك لا `payment_id` له** — ولو
 * رُبط بدفعةٍ لَظهر في الحسابات دخلاً لم يصل.
 *
 * **والمزوّد يجب أن يكون موثَّقاً:** `api_active_promotions` تُسقط غيرَ
 * الموثَّق أصلاً، فلو كُتب صفٌّ لمزوّدٍ معلّقٍ لَبقي في الجدول ولم يظهر في
 * التطبيق — ولا شيءَ يقول لك لماذا.
 */
export async function featureProvider(input: {
  provider: ServiceProvider
  days: number
  amount?: number
}): Promise<void> {
  if (input.days < 1 || input.days > 90) throw new Error('المدّة من يومٍ إلى تسعين.')
  if (input.provider.status !== 'verified') {
    throw new Error('لا يظهر في الشريط إلّا مزوّدٌ موثَّق.')
  }

  const startsAt = new Date()
  const endsAt = new Date(startsAt.getTime() + input.days * 24 * 60 * 60 * 1000)

  if (!isSupabaseConfigured) {
    demoPromotions.unshift({
      id: `featured-${Date.now()}`,
      provider_id: input.provider.id,
      provider_name: input.provider.business_name,
      kind: 'featured',
      placement: 'home',
      category_name: '',
      amount: input.amount ?? 0,
      status: 'active',
      impressions: 0,
      clicks: 0,
      starts_at: startsAt.toISOString(),
      ends_at: endsAt.toISOString(),
    })
    await delay(null, 200)
    return
  }

  const { error } = await requireSupabase().from('promotions').insert({
    provider_id: input.provider.id,
    provider_name: input.provider.business_name,
    kind: 'featured',
    placement: 'home',
    amount: input.amount ?? 0,
    // يبدأ الآن، فيُكتب `active` ويظهر فوراً — ولا شيءَ ينتظره.
    status: 'active',
    starts_at: startsAt.toISOString(),
    ends_at: endsAt.toISOString(),
  })
  if (error) throw error

  await recordAudit({
    action: 'promotion.feature',
    entity: 'promotion',
    entityId: input.provider.id,
    entityLabel: `ظهور مميز — ${input.provider.business_name}`,
    details: {
      days: input.days,
      to: endsAt.toISOString().slice(0, 10),
      ...(input.amount ? { amount: input.amount } : { note: 'بلا مقابل' }),
    },
  })
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
