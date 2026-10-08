import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Hourglass, Search, XCircle } from 'lucide-react'
import { ReviewButtons, RejectServiceDialog } from '@/components/dashboard/ServiceReview'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card, CardHeader } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { Rating } from '@/components/ui/Rating'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney, formatNumber, formatRelative } from '@/lib/format'
import type { ProviderStatus } from '@/lib/types'
import { mockCategories } from '@/data/mock'
import {
  GOVERNORATES,
  PROVIDER_STATUS_LABEL,
  listProviders,
  listServiceReviews,
  reviewService,
  type ServiceReview,
} from '@/services/directory'
import { errorText } from '@/services/base'

const CATEGORY_NAMES = mockCategories.map((category) => category.name)

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<ProviderStatus, Tone> = {
  verified: 'good',
  pending: 'warning',
  suspended: 'critical',
  rejected: 'neutral',
}

export function ProvidersPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<ProviderStatus | 'all'>('all')
  const [category, setCategory] = useState<string | 'all'>('all')
  const [governorate, setGovernorate] = useState<string | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, category, governorate])

  const load = useCallback(
    () =>
      listProviders({
        search: debouncedSearch,
        status,
        category,
        governorate,
        page,
        pageSize: PAGE_SIZE,
      }),
    [debouncedSearch, status, category, governorate, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    category,
    governorate,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listProviders({
      search: debouncedSearch,
      status,
      category,
      governorate,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'الاسم',
        'المؤسسة',
        'البريد',
        'الجوال',
        'الأقسام',
        'المحافظة',
        'الحالة',
        'التقييم',
        'عدد التقييمات',
        'الحجوزات المنفّذة',
        'إجمالي الأرباح',
        'العمولة %',
        'تاريخ التقديم',
        'تاريخ التوثيق',
      ],
      rows: all.rows.map((provider) => [
        provider.full_name,
        provider.business_name,
        provider.email,
        provider.phone,
        provider.categories.join(' / '),
        provider.governorate,
        PROVIDER_STATUS_LABEL[provider.status],
        provider.rating || '',
        provider.reviews_count,
        provider.completed_bookings,
        provider.total_earnings,
        // null means "no override" — the platform-wide rate applies.
        provider.commission_percent ?? '',
        formatDate(provider.applied_at),
        provider.verified_at ? formatDate(provider.verified_at) : '',
      ]),
    }
  }, [debouncedSearch, status, category, governorate])

  return (
    <div className="flex flex-col gap-4">
      {/* ما ينتظر الإدارةَ من الخدمات — يجمعها من كلّ المزوّدين، ويغيب إن لم يكن شيء. */}
      <PendingServicesCard onToast={setToast} onChanged={reload} />

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
            placeholder="ابحث بالاسم أو المؤسسة أو البريد أو الجوال…"
            aria-label="بحث في مقدّمي الخدمة"
            className="ps-9"
          />
        </div>

        <div className="w-44">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as ProviderStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(PROVIDER_STATUS_LABEL) as ProviderStatus[]).map((key) => (
              <option key={key} value={key}>
                {PROVIDER_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-36">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value)}
            aria-label="تصفية حسب القسم"
          >
            <option value="all">كل الأقسام</option>
            {CATEGORY_NAMES.map((entry) => (
              <option key={entry} value={entry}>
                {entry}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={governorate}
            onChange={(event) => setGovernorate(event.target.value)}
            aria-label="تصفية حسب المحافظة"
          >
            <option value="all">كل المحافظات</option>
            {GOVERNORATES.map((entry) => (
              <option key={entry} value={entry}>
                {entry}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-مقدمي-الخدمة"
          build={buildExport}
          disabled={!data || data.total === 0}
          onError={setToast}
        />
      </div>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState
            title="لا توجد نتائج"
            description="جرّب تعديل كلمات البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {[
                    'مقدّم الخدمة',
                    'الأقسام',
                    'المحافظة',
                    'التقييم',
                    'الحجوزات',
                    'الأرباح',
                    'العمولة',
                    'الحالة',
                  ].map((heading) => (
                    <th
                      key={heading}
                      scope="col"
                      className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((provider) => (
                  <tr
                    key={provider.id}
                    className="glass-row border-b border-hairline last:border-0"
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/providers/${provider.id}`}
                        className="font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                      >
                        {provider.full_name}
                      </Link>
                      <p className="text-xs text-muted">{provider.business_name}</p>
                    </td>
                    <td className="px-4 py-3 text-xs text-ink-2">
                      {provider.categories.join('، ') || '—'}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {provider.governorate}
                    </td>
                    <td className="px-4 py-3">
                      <Rating value={provider.rating} count={provider.reviews_count} />
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatNumber(provider.completed_bookings)}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatMoney(provider.total_earnings)}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {provider.commission_percent === null
                        ? 'العامة'
                        : `${provider.commission_percent}%`}
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        tone={STATUS_TONE[provider.status]}
                        icon={provider.status === 'rejected' ? XCircle : true}
                      >
                        {PROVIDER_STATUS_LABEL[provider.status]}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {data && data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
        ) : null}
      </Card>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

/**
 * **«خدماتٌ بانتظار موافقتك»** — اختيارُ صاحب المنصّة (ج): مقدّمُ الخدمة يختار أيَّ
 * قسمٍ لخدمته، وما ليس من أقسامه ينتظر هنا. فتُقبل أو تُرفض بسبب — **والموافقةُ
 * تضيف قسمَها لأقسامه** (ب)، فكان رابطُ «أضف القسم لأقسامه» زائداً فرُفع.
 */
function PendingServicesCard({
  onToast,
  onChanged,
}: {
  onToast: (message: string) => void
  onChanged: () => void
}) {
  const { can } = useAuth()
  const canWrite = can('directory')
  const reviews = useAsync(listServiceReviews, [])
  const [busy, setBusy] = useState(false)
  const [rejecting, setRejecting] = useState<ServiceReview | null>(null)
  const [rejectError, setRejectError] = useState<string | null>(null)

  const rows = reviews.data ?? []
  if (rows.length === 0) return null
  const pending = rows.filter((r) => r.approval === 'pending').length

  async function decide(review: ServiceReview, approve: boolean, note = '') {
    setBusy(true)
    setRejectError(null)
    try {
      await reviewService(review, approve, note)
      setRejecting(null)
      onToast(
        approve
          ? `ظهرت الخدمة للعملاء — وأُضيف «${review.category_name}» لأقسام ${review.provider_name}.`
          : `رُفضت «${review.title}» — وصل السببُ صاحبَها.`,
      )
      reviews.reload()
      // أقسامُه تغيّرت بالموافقة، فعمودُ «الأقسام» في القائمة يُعاد.
      if (approve) onChanged()
    } catch (cause) {
      const message = errorText(cause, 'تعذّرت المراجعة.')
      if (approve) onToast(message)
      else setRejectError(message)
    } finally {
      setBusy(false)
    }
  }

  return (
    // `Card` لا يمرّر سماتٍ أخرى، فالعلامةُ على غلافٍ حوله.
    <div data-pending-services={pending}>
      <Card className={cn('overflow-hidden', reviews.refetching && 'is-refetching')}>
        <CardHeader
          title={`خدماتٌ بانتظار موافقتك (${formatNumber(pending)})`}
          subtitle="أضافها مقدّمو خدمة في قسمٍ ليس من أقسامهم — لا يراها العملاءُ حتى توافق."
        />
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-xs">
            <thead>
              <tr className="glass-item">
                {['الخدمة', 'مقدّم الخدمة', 'قسمُها', 'أقسامُه', 'السعر', ''].map((heading, index) => (
                  <th
                    key={index}
                    scope="col"
                    className="border-b border-hairline px-4 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                  >
                    {heading}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((review) => (
                <tr
                  key={review.id}
                  data-review={review.approval}
                  className="glass-row border-b border-hairline last:border-0"
                >
                  <td className="px-4 py-2.5 font-semibold text-ink">
                    {review.title}
                    <span className="block text-[11px] font-normal text-muted">
                      {review.approval === 'rejected'
                        ? `مرفوضة — ${review.approval_note}`
                        : formatRelative(review.created_at)}
                    </span>
                  </td>
                  <td className="px-4 py-2.5">
                    <Link
                      to={`/providers/${review.provider_id}`}
                      className="text-ink underline-offset-4 hover:text-accent hover:underline"
                    >
                      {review.provider_name}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5">
                    <Badge tone={review.approval === 'pending' ? 'warning' : 'critical'} icon={review.approval === 'pending' ? Hourglass : XCircle}>
                      {review.category_name}
                    </Badge>
                  </td>
                  <td className="px-4 py-2.5 text-muted">{review.provider_categories || '—'}</td>
                  <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink">{formatMoney(review.price)}</td>
                  <td className="px-4 py-2.5 whitespace-nowrap">
                    <ReviewButtons
                      review={review}
                      canWrite={canWrite}
                      busy={busy}
                      onApprove={(r) => decide(r, true)}
                      onReject={(r) => {
                        setRejectError(null)
                        setRejecting(r)
                      }}
                      hint={`الموافقةُ تضيف «${review.category_name}» لأقسام ${review.provider_name}`}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <RejectServiceDialog
          review={rejecting}
          busy={busy}
          error={rejectError}
          onConfirm={(review, note) => decide(review, false, note)}
          onCancel={() => setRejecting(null)}
        />
      </Card>
    </div>
  )
}
