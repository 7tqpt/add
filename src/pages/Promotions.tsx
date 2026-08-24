import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Ban, Search } from 'lucide-react'
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
import type { Promotion, PromotionKind, PromotionStatus, SubscriptionPlan } from '@/lib/types'
import {
  PROMOTION_KIND_LABEL,
  PROMOTION_STATUS_LABEL,
  cancelPromotion,
  clickRate,
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
