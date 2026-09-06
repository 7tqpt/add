import { useCallback, useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Ban, ImagePlus, Megaphone, Search, Star, X } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import {
  DAY_FORMS,
  formatCount,
  formatDate,
  formatMoney,
  formatNumber,
  formatPercent,
} from '@/lib/format'
import type {
  Promotion,
  PromotionKind,
  PromotionStatus,
  ServiceProvider,
  SubscriptionPlan,
} from '@/lib/types'
import { listProviders } from '@/services/directory'
import {
  MAX_BANNER_IMAGES,
  PROMOTION_KIND_LABEL,
  PROMOTION_STATUS_LABEL,
  cancelPromotion,
  clickRate,
  createBanner,
  featureProvider,
  listPromotions,
  listSubscriptionPlans,
  setSubscriptionPlanActive,
} from '@/services/growth'
import { errorText } from '@/services/base'

const PAGE_SIZE = 10

const STATUS_TONE: Record<PromotionStatus, Tone> = {
  scheduled: 'warning',
  active: 'good',
  ended: 'neutral',
  cancelled: 'critical',
}

export function PromotionsPage() {
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  return (
    <div className="flex flex-col gap-5">
      <SubscriptionPlans onToast={setToast} />
      <FeatureProviderCard onToast={setToast} />
      <NewBannerCard onToast={setToast} />
      <Campaigns onToast={setToast} />
      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

// ---------------------------------------------------------------------------

function SubscriptionPlans({ onToast }: { onToast: (message: string) => void }) {
  const { can } = useAuth()
  const canWrite = can('finance')
  const [busyId, setBusyId] = useState<string | null>(null)
  const { data, error, loading, refetching, reload } = useAsync(listSubscriptionPlans, [])

  async function toggle(plan: SubscriptionPlan, next: boolean) {
    setBusyId(plan.id)
    try {
      await setSubscriptionPlanActive(plan, next)
      onToast(next ? `أُتيحت باقة «${plan.name}».` : `أُوقفت باقة «${plan.name}».`)
      reload()
    } catch (cause) {
      onToast(errorText(cause, 'تعذّر تنفيذ الإجراء.'))
    } finally {
      setBusyId(null)
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <div>
        <h2 className="text-sm font-semibold text-ink">باقات اشتراك مقدّمي الخدمة</h2>
        <p className="mt-0.5 text-xs text-muted">
          إيراد ثابت مقابل ميزات إضافية — إيقاف باقة يمنع الاشتراكات الجديدة فقط ولا يلغي
          الاشتراكات السارية.
        </p>
      </div>

      {loading ? (
        <Card>
          <LoadingBlock />
        </Card>
      ) : error && !data ? (
        <Card>
          <ErrorState message={error} onRetry={reload} />
        </Card>
      ) : (
        <div
          className={cn(
            'grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3',
            refetching && 'is-refetching',
          )}
        >
          {(data ?? []).map((plan) => (
            <Card key={plan.id}>
              <CardHeader
                title={plan.name}
                subtitle={
                  // A price of zero is the free tier, not a 0-riyal charge.
                  plan.price === 0
                    ? 'مجانية'
                    : `${formatMoney(plan.price)} / ${formatCount(plan.duration_days, DAY_FORMS)}`
                }
                actions={
                  <Badge tone={plan.is_active ? 'good' : 'neutral'}>
                    {plan.is_active ? 'متاحة' : 'موقوفة'}
                  </Badge>
                }
              />
              <CardBody className="flex flex-col gap-3">
                <p className="text-xs leading-6 text-ink-2">{plan.description}</p>
                <ul className="flex flex-col gap-1 text-xs text-ink-2">
                  {plan.perks.map((perk) => (
                    <li key={perk}>• {perk}</li>
                  ))}
                </ul>
                <p className="tnum text-xs text-muted">
                  {formatNumber(plan.subscribers_count)} مشترك حالياً
                </p>
                <Toggle
                  checked={plan.is_active}
                  disabled={!canWrite || busyId === plan.id}
                  onChange={(next) => toggle(plan, next)}
                  label="متاحة للاشتراك"
                />
              </CardBody>
            </Card>
          ))}
        </div>
      )}
    </section>
  )
}

// ---------------------------------------------------------------------------

/**
 * بحثٌ عن مزوّدٍ موثَّق واختيارُه.
 *
 * **والموثَّقون وحدهم:** `api_active_promotions` تُسقط غيرَهم، فاختيارُ مزوّدٍ
 * معلّقٍ هنا يكتب صفّاً لا يظهر في التطبيق أبداً ولا شيءَ يقول لماذا.
 */
function ProviderPicker({
  value,
  onPick,
  disabled,
}: {
  value: ServiceProvider | null
  onPick: (provider: ServiceProvider | null) => void
  disabled?: boolean
}) {
  const [search, setSearch] = useState('')
  const [rows, setRows] = useState<ServiceProvider[]>([])
  const [busy, setBusy] = useState(false)
  const debounced = useDebounced(search)

  useEffect(() => {
    const term = debounced.trim()
    if (value || term.length < 2) {
      setRows([])
      return
    }
    let alive = true
    setBusy(true)
    listProviders({
      search: term,
      status: 'verified',
      category: 'all',
      governorate: 'all',
      page: 0,
      pageSize: 6,
    })
      .then((paged) => {
        if (alive) setRows(paged.rows)
      })
      .catch(() => {
        if (alive) setRows([])
      })
      .finally(() => {
        if (alive) setBusy(false)
      })
    return () => {
      alive = false
    }
  }, [debounced, value])

  if (value) {
    return (
      <div className="flex items-center justify-between gap-3 rounded-lg border border-hairline px-3 py-2">
        <div className="flex flex-col">
          <span className="text-sm text-ink">{value.business_name}</span>
          <span className="text-[11px] text-muted">{value.governorate}</span>
        </div>
        <button
          type="button"
          disabled={disabled}
          onClick={() => onPick(null)}
          className="text-xs text-accent transition hover:underline disabled:opacity-50"
        >
          غيّره
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-1.5">
      <Input
        value={search}
        disabled={disabled}
        onChange={(event) => setSearch(event.target.value)}
        placeholder="ابحث باسم النشاط أو صاحبه…"
      />
      {busy ? <p className="text-[11px] text-muted">يبحث…</p> : null}
      {rows.length ? (
        <ul className="flex flex-col overflow-hidden rounded-lg border border-hairline">
          {rows.map((provider) => (
            <li key={provider.id}>
              <button
                type="button"
                onClick={() => {
                  onPick(provider)
                  setSearch('')
                }}
                className="flex w-full items-center justify-between gap-3 px-3 py-2 text-start transition hover:bg-surface-2"
              >
                <span className="text-sm text-ink">{provider.business_name}</span>
                <span className="text-[11px] text-muted">{provider.governorate}</span>
              </button>
            </li>
          ))}
        </ul>
      ) : debounced.trim().length >= 2 && !busy ? (
        <p className="text-[11px] text-muted">لا مزوّدَ موثَّقاً بهذا الاسم.</p>
      ) : null}
    </div>
  )
}

/**
 * وضعُ مزوّدٍ في شريط «مزوّدون مميّزون» من اللوحة — بلا حوالةٍ ولا انتظار.
 *
 * والمسار الأصليّ للبيع باقٍ كما هو: المزوّد يطلب من تطبيقه، فتُنشأ دفعةٌ
 * معلّقة، وتُفعَّل حين تُؤكَّد حوالتُه من صفحة المدفوعات.
 */
function FeatureProviderCard({ onToast }: { onToast: (message: string) => void }) {
  const { canWrite } = useAuth()
  const [provider, setProvider] = useState<ServiceProvider | null>(null)
  const [days, setDays] = useState('30')
  const [busy, setBusy] = useState(false)

  async function submit() {
    if (!provider) return
    setBusy(true)
    try {
      await featureProvider({ provider, days: Number(days) })
      onToast('صار في شريط المميّزين.')
      setProvider(null)
      setDays('30')
    } catch (cause) {
      onToast(errorText(cause, 'تعذّر وضعُه في الشريط.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card>
      <CardHeader
        title={
          <span className="flex items-center gap-2">
            <Star className="size-4" />
            ظهور مميّز — وضعٌ يدويّ
          </span>
        }
        subtitle="يبدأ فوراً وبلا مقابل. والبيعُ مسارُه الآخر: المزوّد يطلب من تطبيقه ثمّ تُؤكَّد حوالتُه من المدفوعات."
      />
      <CardBody className="flex flex-col gap-4">
        <div className="grid gap-3 sm:grid-cols-[2fr_1fr]">
          <Field label="المزوّد" hint="الموثَّقون وحدهم — غيرُهم لا يظهر في الشريط.">
            {() => (
              <ProviderPicker value={provider} onPick={setProvider} disabled={busy} />
            )}
          </Field>
          <Field label="المدّة بالأيام">
            {(id) => (
              <Input
                id={id}
                type="number"
                min={1}
                max={90}
                dir="ltr"
                className="tnum text-start"
                value={days}
                onChange={(event) => setDays(event.target.value)}
              />
            )}
          </Field>
        </div>

        <div className="flex justify-start">
          <Button
            onClick={submit}
            disabled={!canWrite || busy || !provider || Number(days) < 1 || Number(days) > 90}
          >
            {busy ? 'يُضاف…' : 'ضعه في الشريط'}
          </Button>
        </div>
      </CardBody>
    </Card>
  )
}

/** حدُّ سلّة اللافتات في القاعدة — ميجابايتان. */
const MAX_BANNER_BYTES = 2 * 1024 * 1024

/** يوم بصيغة `yyyy-mm-dd` كما يقبلها حقل التاريخ. */
function isoDay(offsetDays: number): string {
  const day = new Date()
  day.setDate(day.getDate() + offsetDays)
  return day.toISOString().slice(0, 10)
}

/**
 * إنشاء لافتة إعلانية لأعلى الرئيسية في التطبيق.
 *
 * **والمساحة هي التي كانت لبطاقتَي «خطة العرس» و«حجوزاتي»** — فما يُرفع هنا
 * يقع في أوّل ما تراه العين حين يُفتح التطبيق.
 *
 * والصورة عريضة: البطاقة في الجوال ‎٣١٧×١٩٦‎ تقريباً، فنسبةُ ‎١٦:١٠‎ تملؤها
 * بلا قصٍّ يبتلع نصفَ التصميم.
 */
function NewBannerCard({ onToast }: { onToast: (message: string) => void }) {
  const { canWrite } = useAuth()
  const input = useRef<HTMLInputElement>(null)
  const [files, setFiles] = useState<File[]>([])
  const [previews, setPreviews] = useState<string[]>([])
  const [headline, setHeadline] = useState('')
  const [startsAt, setStartsAt] = useState(isoDay(0))
  const [endsAt, setEndsAt] = useState(isoDay(30))
  const [provider, setProvider] = useState<ServiceProvider | null>(null)
  const [busy, setBusy] = useState(false)
  const [rejected, setRejected] = useState('')

  // روابط المعاينة تُلغى مع الملفّات: تركُها يُبقي الصور كلَّها في الذاكرة.
  useEffect(() => {
    const urls = files.map((file) => URL.createObjectURL(file))
    setPreviews(urls)
    return () => urls.forEach((url) => URL.revokeObjectURL(url))
  }, [files])

  function choose(picked: FileList | null) {
    if (!picked || picked.length === 0) return
    const incoming = Array.from(picked)

    const tooBig = incoming.filter((file) => file.size > MAX_BANNER_BYTES)
    const room = MAX_BANNER_IMAGES - files.length
    const fitting = incoming.filter((file) => file.size <= MAX_BANNER_BYTES).slice(0, room)

    // **ويُقال ما رُفض ولماذا، لا يُبتلع صامتاً.** من اختار خمس صورٍ فدخلت
    // ثلاثٌ بلا كلمةٍ يظنّ أنّ الخمسَ دخلت، ويكتشف النقصَ في جوّال زبونه.
    const notes: string[] = []
    if (tooBig.length) notes.push(`${tooBig.length} أكبر من ميجابايتين`)
    const overflow = incoming.length - tooBig.length - fitting.length
    if (overflow > 0) notes.push(`${overflow} تجاوزت حدَّ ${MAX_BANNER_IMAGES} صور`)
    setRejected(notes.length ? `لم تُضَف: ${notes.join('، ')}.` : '')

    if (fitting.length) setFiles((current) => [...current, ...fitting])
  }

  function drop(index: number) {
    setFiles((current) => current.filter((_, i) => i !== index))
    setRejected('')
  }

  async function submit() {
    if (files.length === 0) return
    setBusy(true)
    try {
      await createBanner({
        files,
        headline,
        starts_at: startsAt,
        // آخرُ اليوم لا أوّلُه: من كتب «تنتهي ٣٠ يونيو» يقصد أن تُعرض ذلك
        // اليوم كلَّه، لا أن تختفي في منتصف ليلته الأولى.
        ends_at: `${endsAt}T23:59:59`,
        provider_id: provider?.id,
      })
      onToast(
        files.length > 1 ? `نُشرت اللافتة بـ${files.length} صور.` : 'نُشرت اللافتة.',
      )
      setFiles([])
      setHeadline('')
      setProvider(null)
      setRejected('')
    } catch (cause) {
      onToast(errorText(cause, 'تعذّر نشر اللافتة.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card>
      <CardHeader
        title={
          <span className="flex items-center gap-2">
            <Megaphone className="size-4" />
            لافتة إعلانية جديدة
          </span>
        }
        subtitle="تُعرض في أعلى الرئيسية في التطبيق، وتُمرَّر مع غيرها كل ثلاث ثوانٍ."
      />
      <CardBody className="flex flex-col gap-4">
        <div className="flex flex-wrap items-start gap-4">
          {/* المعاينة كما تظهر في الجوال: الصورة الأولى وفوقها الكلمات
              بالستار نفسِه الذي يرسمه التطبيق — فما يُرى هنا هو ما يُرى هناك. */}
          <div className="relative flex h-[124px] w-[198px] shrink-0 items-center justify-center overflow-hidden rounded-xl border border-hairline bg-surface-2">
            {previews[0] ? (
              <>
                <img src={previews[0]} alt="معاينة اللافتة" className="h-full w-full object-cover" />
                {headline.trim() ? (
                  <>
                    <span
                      aria-hidden
                      className="pointer-events-none absolute inset-0 bg-gradient-to-t from-ink/80 via-ink/30 to-transparent"
                    />
                    <span className="absolute inset-x-2.5 bottom-2 line-clamp-2 text-[12px] font-bold leading-snug text-white">
                      {headline.trim()}
                    </span>
                  </>
                ) : null}
                <span className="absolute start-1.5 top-1.5 rounded-md bg-ink/55 px-1.5 py-0.5 text-[9px] text-white">
                  إعلان
                </span>
              </>
            ) : (
              <span className="text-[11px] text-muted">مقاسها في الجوال</span>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <button
              type="button"
              disabled={!canWrite || busy || files.length >= MAX_BANNER_IMAGES}
              onClick={() => input.current?.click()}
              className="flex items-center gap-1.5 rounded-lg border border-hairline px-2.5 py-1 text-xs text-ink-2 transition hover:border-accent hover:text-accent disabled:cursor-not-allowed disabled:opacity-50"
            >
              <ImagePlus className="size-3.5" />
              {files.length ? 'أضف صوراً' : 'اختر صوراً'}
            </button>
            <p className="max-w-[22rem] text-[11px] leading-5 text-muted">
              صورةٌ عريضة بنسبة ‎١٦:١٠‎ تقريباً (‎١٢٨٠×٨٠٠‎ مثلاً)، بحدٍّ أقصى
              ميجابايتان لكلٍّ. ولك أن تختار حتى {MAX_BANNER_IMAGES} صورٍ للحملة
              الواحدة — تُمرَّر شريحةً بعد شريحة، وتحمل كلُّها الكلماتِ
              والوجهةَ نفسَها.
            </p>
            {rejected ? (
              <p className="text-[11px] leading-5 text-critical">{rejected}</p>
            ) : null}
          </div>
        </div>

        {/* شريطُ الصور المختارة — وكلٌّ تُنزع وحدَها. */}
        {previews.length > 1 ? (
          <div className="flex flex-wrap gap-2">
            {previews.map((url, index) => (
              <div
                key={url}
                className="relative h-[52px] w-[84px] overflow-hidden rounded-lg border border-hairline"
              >
                <img src={url} alt="" className="h-full w-full object-cover" />
                <span className="absolute bottom-0 start-0 bg-ink/65 px-1 text-[9px] text-white">
                  {index + 1}
                </span>
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => drop(index)}
                  aria-label={`انزع الصورة ${index + 1}`}
                  className="absolute end-0.5 top-0.5 rounded-full bg-ink/70 p-0.5 text-white transition hover:bg-critical disabled:opacity-50"
                >
                  <X className="size-3" />
                </button>
              </div>
            ))}
          </div>
        ) : null}

        <input
          ref={input}
          type="file"
          multiple
          accept="image/jpeg,image/png,image/webp"
          className="hidden"
          onChange={(event) => {
            choose(event.target.files)
            // يُفرَّغ ليقبل اختيار الملفّ نفسه مرّةً ثانية بعد نزعه.
            event.target.value = ''
          }}
        />

        <Field
          label="كلمات الإعلان (اختياري)"
          hint="تُكتب فوق الصور كلِّها في أسفلها. وتُترك فارغةً فلا يُكتب شيء."
        >
          {(id) => (
            <Input
              id={id}
              value={headline}
              maxLength={70}
              placeholder="خصمُ ٢٠٪ على حجوزات رمضان"
              onChange={(event) => setHeadline(event.target.value)}
            />
          )}
        </Field>

        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="تبدأ">
            {(id) => (
              <Input
                id={id}
                type="date"
                value={startsAt}
                onChange={(event) => setStartsAt(event.target.value)}
              />
            )}
          </Field>
          <Field label="تنتهي">
            {(id) => (
              <Input
                id={id}
                type="date"
                value={endsAt}
                onChange={(event) => setEndsAt(event.target.value)}
              />
            )}
          </Field>
          <Field
            label="المزوّد (اختياري)"
            hint="تُفتح صفحته بالضغط على اللافتة. ويُترك فارغاً فلا تُضغط."
          >
            {() => (
              // **ولا يُكتب المعرّفُ بيده.** كان حقلَ `uuid` يُلصق فيه —
              // وحرفٌ ناقصٌ يعني لافتةً تُضغط فتفتح شاشةً فارغة، ولا شيءَ
              // يقول أين الخطأ.
              <ProviderPicker value={provider} onPick={setProvider} disabled={busy} />
            )}
          </Field>
        </div>

        <div className="flex justify-start">
          <Button onClick={submit} disabled={!canWrite || busy || files.length === 0}>
            {busy ? 'يُنشر…' : 'انشر اللافتة'}
          </Button>
        </div>
      </CardBody>
    </Card>
  )
}

function Campaigns({ onToast }: { onToast: (message: string) => void }) {
  const { canWrite } = useAuth()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<PromotionStatus | 'all'>('all')
  const [kind, setKind] = useState<PromotionKind | 'all'>('all')
  const [page, setPage] = useState(0)
  const [cancelling, setCancelling] = useState<Promotion | null>(null)
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, kind])

  const load = useCallback(
    () => listPromotions({ search: debouncedSearch, status, kind, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, kind, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    kind,
    page,
  ])

  async function run() {
    if (!cancelling) return
    setBusy(true)
    try {
      await cancelPromotion(cancelling, reason.trim())
      onToast('أُلغيت الحملة.')
      reload()
    } catch (cause) {
      onToast(errorText(cause, 'تعذّر إلغاء الحملة.'))
    } finally {
      setBusy(false)
      setCancelling(null)
      setReason('')
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <div>
        <h2 className="text-sm font-semibold text-ink">الحملات الترويجية</h2>
        <p className="mt-0.5 text-xs text-muted">
          مساحات مدفوعة يشتريها مقدّمو الخدمة لإبراز أعمالهم داخل التطبيق.
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-56 flex-1">
          <Search
            size={15}
            aria-hidden
            className="pointer-events-none absolute top-1/2 start-3 -translate-y-1/2 text-muted"
          />
          <Input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="ابحث باسم الشريك أو موضع الظهور…"
            aria-label="بحث في الحملات"
            className="ps-9"
          />
        </div>

        <div className="w-36">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as PromotionStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(PROMOTION_STATUS_LABEL) as PromotionStatus[]).map((key) => (
              <option key={key} value={key}>
                {PROMOTION_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={kind}
            onChange={(event) => setKind(event.target.value as PromotionKind | 'all')}
            aria-label="تصفية حسب النوع"
          >
            <option value="all">كل الأنواع</option>
            {(Object.keys(PROMOTION_KIND_LABEL) as PromotionKind[]).map((key) => (
              <option key={key} value={key}>
                {PROMOTION_KIND_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>
      </div>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState title="لا توجد حملات" description="جرّب تعديل البحث أو عوامل التصفية." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {['الشريك', 'النوع', 'الفترة', 'المبلغ', 'الظهور', 'النقر', 'الحالة', ''].map(
                    (heading, index) => (
                      <th
                        key={index}
                        scope="col"
                        className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                      >
                        {heading}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((promotion) => {
                  const rate = clickRate(promotion)
                  return (
                    <tr
                      key={promotion.id}
                      className="glass-row border-b border-hairline last:border-0"
                    >
                      <td className="px-4 py-3">
                        <Link
                          to={`/providers/${promotion.provider_id}`}
                          className="text-xs font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                        >
                          {promotion.provider_name}
                        </Link>
                        <p className="text-[11px] text-muted">{promotion.placement}</p>
                      </td>
                      <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {PROMOTION_KIND_LABEL[promotion.kind]}
                        {promotion.category_name ? (
                          <span className="block text-[11px] text-muted">
                            {promotion.category_name}
                          </span>
                        ) : null}
                      </td>
                      <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatDate(promotion.starts_at)} — {formatDate(promotion.ends_at)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(promotion.amount)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(promotion.impressions)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(promotion.clicks)}
                        <span className="block text-[11px] text-muted">
                          {/* No impressions means not measured, not a 0% rate. */}
                          {rate === null ? '—' : formatPercent(rate)}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone={STATUS_TONE[promotion.status]}>
                          {PROMOTION_STATUS_LABEL[promotion.status]}
                        </Badge>
                      </td>
                      <td className="px-4 py-3 text-end">
                        {promotion.status === 'scheduled' || promotion.status === 'active' ? (
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy || !canWrite}
                            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                            onClick={() => setCancelling(promotion)}
                          >
                            <Ban size={14} aria-hidden />
                            إلغاء
                          </Button>
                        ) : null}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {data && data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
        ) : null}
      </Card>

      <ConfirmDialog
        open={cancelling !== null}
        title="إلغاء الحملة؟"
        message={
          cancelling
            ? `ستتوقف حملة ${cancelling.provider_name} فوراً. ردّ المبلغ (${formatMoney(cancelling.amount)}) يُنفَّذ يدوياً من شاشة عمليات الدفع إن كان مستحقاً.`
            : ''
        }
        confirmLabel="تأكيد الإلغاء"
        busy={busy}
        onConfirm={run}
        onCancel={() => {
          setCancelling(null)
          setReason('')
        }}
      >
        <Field label="سبب الإلغاء" hint="يظهر في سجل العمليات.">
          {(fieldId) => (
            <Textarea
              id={fieldId}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="مثال: طلب الشريك إيقاف الحملة مبكراً."
            />
          )}
        </Field>
      </ConfirmDialog>
    </section>
  )
}
