import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search, XCircle } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney, formatTime } from '@/lib/format'
import type { BookingStatus } from '@/lib/types'
import { mockCategories } from '@/data/mock'
import { BOOKING_STATUS_LABEL, listBookings } from '@/services/bookings'
import { GOVERNORATES } from '@/services/directory'

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

const CATEGORY_NAMES = mockCategories.map((category) => category.name)

export const BOOKING_STATUS_TONE: Record<BookingStatus, Tone> = {
  pending_provider: 'warning',
  confirmed: 'good',
  completed: 'good',
  rejected: 'critical',
  cancelled: 'critical',
  expired: 'neutral',
}

const RANGES: { value: number | 'all'; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
  { value: 'all', label: 'كل الفترات' },
]

export function BookingsPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<BookingStatus | 'all'>('all')
  const [category, setCategory] = useState<string | 'all'>('all')
  const [governorate, setGovernorate] = useState<string | 'all'>('all')
  const [days, setDays] = useState<number | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, category, governorate, days])

  const load = useCallback(
    () =>
      listBookings({
        search: debouncedSearch,
        status,
        category,
        governorate,
        days,
        page,
        pageSize: PAGE_SIZE,
      }),
    [debouncedSearch, status, category, governorate, days, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    category,
    governorate,
    days,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listBookings({
      search: debouncedSearch,
      status,
      category,
      governorate,
      days,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'رقم الحجز',
        'العميل',
        'مقدّم الخدمة',
        'الخدمة',
        'القسم',
        'المحافظة',
        'تاريخ المناسبة',
        'الحالة',
        'الإجمالي',
        'العربون',
        'المدفوع',
        'المسترجع',
        'العمولة',
        'تاريخ الحجز',
      ],
      rows: all.rows.map((booking) => [
        booking.reference,
        booking.user_name,
        booking.provider_name,
        booking.service_title,
        booking.category_name,
        booking.governorate,
        formatDate(booking.event_date),
        BOOKING_STATUS_LABEL[booking.status],
        booking.total_price,
        booking.deposit_amount,
        booking.paid_amount,
        booking.refunded_amount,
        booking.commission_amount,
        formatDate(booking.created_at),
      ]),
    }
  }, [debouncedSearch, status, category, governorate, days])

  return (
    <div className="flex flex-col gap-4">
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
            placeholder="ابحث برقم الحجز أو العميل أو مقدّم الخدمة…"
            aria-label="بحث في الحجوزات"
            className="ps-9"
          />
        </div>

        <div className="w-48">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as BookingStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(BOOKING_STATUS_LABEL) as BookingStatus[]).map((key) => (
              <option key={key} value={key}>
                {BOOKING_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value)}
            aria-label="تصفية حسب القسم"
          >
            <option value="all">كل الأقسام</option>
            {CATEGORY_NAMES.map((name) => (
              <option key={name} value={name}>
                {name}
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
            {GOVERNORATES.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-36">
          <Select
            value={String(days)}
            onChange={(event) =>
              setDays(event.target.value === 'all' ? 'all' : Number(event.target.value))
            }
            aria-label="تصفية حسب الفترة"
          >
            {RANGES.map((range) => (
              <option key={String(range.value)} value={String(range.value)}>
                {range.label}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-الحجوزات"
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
            title="لا توجد حجوزات"
            description="جرّب تعديل كلمات البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {[
                    'رقم الحجز',
                    'العميل',
                    'مقدّم الخدمة',
                    'الخدمة',
                    'موعد المناسبة',
                    'الإجمالي',
                    'المدفوع',
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
                {data.rows.map((booking) => (
                  <tr
                    key={booking.id}
                    className="glass-row border-b border-hairline last:border-0"
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/bookings/${booking.id}`}
                        dir="ltr"
                        className="tnum block text-start font-medium whitespace-nowrap text-ink underline-offset-4 hover:text-accent hover:underline"
                      >
                        {booking.reference}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {booking.user_name}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {booking.provider_name}
                    </td>
                    <td className="px-4 py-3">
                      <p className="text-xs text-ink">{booking.service_title}</p>
                      <p className="text-[11px] text-muted">
                        {booking.category_name} · {booking.governorate}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatDate(booking.event_date)}
                      <span className="tnum block text-[11px] text-muted">
                        {formatTime(booking.event_time)}
                      </span>
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatMoney(booking.total_price)}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatMoney(booking.paid_amount)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        tone={BOOKING_STATUS_TONE[booking.status]}
                        icon={booking.status === 'expired' ? XCircle : true}
                      >
                        {BOOKING_STATUS_LABEL[booking.status]}
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
