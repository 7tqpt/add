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
import { formatDate, formatDateTime, formatMoney } from '@/lib/format'
import type { OrderStatus } from '@/lib/types'
import {
  ORDER_STATUS_LABEL,
  PROVIDER_CATEGORIES,
  PROVIDER_CITIES,
  listOrders,
} from '@/services/orders'

const PAGE_SIZE = 12
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<OrderStatus, Tone> = {
  new: 'warning',
  confirmed: 'good',
  on_the_way: 'good',
  in_progress: 'good',
  completed: 'good',
  closed: 'neutral',
  cancelled: 'critical',
}

const RANGES: { value: number | 'all'; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
  { value: 'all', label: 'كل الفترات' },
]

export function OrdersPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<OrderStatus | 'all'>('all')
  const [category, setCategory] = useState<string | 'all'>('all')
  const [city, setCity] = useState<string | 'all'>('all')
  const [days, setDays] = useState<number | 'all'>(30)
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, category, city, days])

  const load = useCallback(
    () =>
      listOrders({
        search: debouncedSearch,
        status,
        category,
        city,
        days,
        page,
        pageSize: PAGE_SIZE,
      }),
    [debouncedSearch, status, category, city, days, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    category,
    city,
    days,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listOrders({
      search: debouncedSearch,
      status,
      category,
      city,
      days,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'المرجع',
        'العميل',
        'مقدّم الخدمة',
        'الفئة',
        'المدينة',
        'الحالة',
        'الموعد',
        'رسم الحجز',
        'السعر النهائي',
        'حصة المنصة',
        'تاريخ الإنشاء',
      ],
      rows: all.rows.map((order) => [
        order.reference,
        order.user_name,
        order.provider_name,
        order.category,
        order.city,
        ORDER_STATUS_LABEL[order.status],
        formatDateTime(order.scheduled_at),
        order.booking_fee,
        order.final_price || '',
        order.platform_share || '',
        formatDate(order.created_at),
      ]),
    }
  }, [debouncedSearch, status, category, city, days])

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
            placeholder="ابحث بالمرجع أو العميل أو مقدّم الخدمة…"
            aria-label="بحث في الطلبات"
            className="ps-9"
          />
        </div>

        <div className="w-36">
          <Select
            value={String(days)}
            onChange={(event) =>
              setDays(event.target.value === 'all' ? 'all' : Number(event.target.value))
            }
            aria-label="الفترة الزمنية"
          >
            {RANGES.map((range) => (
              <option key={String(range.value)} value={String(range.value)}>
                {range.label}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as OrderStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(ORDER_STATUS_LABEL) as OrderStatus[]).map((key) => (
              <option key={key} value={key}>
                {ORDER_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-32">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value)}
            aria-label="تصفية حسب الفئة"
          >
            <option value="all">كل الفئات</option>
            {PROVIDER_CATEGORIES.map((entry) => (
              <option key={entry} value={entry}>
                {entry}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-28">
          <Select
            value={city}
            onChange={(event) => setCity(event.target.value)}
            aria-label="تصفية حسب المدينة"
          >
            <option value="all">كل المدن</option>
            {PROVIDER_CITIES.map((entry) => (
              <option key={entry} value={entry}>
                {entry}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-الطلبات"
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
            title="لا توجد طلبات"
            description="جرّب توسيع الفترة الزمنية أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {[
                    'الطلب',
                    'العميل',
                    'مقدّم الخدمة',
                    'المدينة',
                    'الموعد',
                    'السعر',
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
                {data.rows.map((order) => (
                  <tr
                    key={order.id}
                    className="border-b border-hairline last:border-0 hover:bg-surface-2"
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/orders/${order.id}`}
                        dir="ltr"
                        className="tnum block text-start text-xs font-medium text-ink underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {order.reference}
                      </Link>
                      <p className="text-xs text-muted">{order.category}</p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      <Link
                        to={`/users/${order.user_id}`}
                        className="underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {order.user_name}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {order.provider_id ? (
                        <Link
                          to={`/providers/${order.provider_id}`}
                          className="underline-offset-4 hover:text-series-1 hover:underline"
                        >
                          {order.provider_name}
                        </Link>
                      ) : (
                        <span className="text-muted">— لم يُقبل عرض بعد</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">{order.city}</td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatDateTime(order.scheduled_at)}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink">
                      {order.final_price ? formatMoney(order.final_price) : '—'}
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        tone={STATUS_TONE[order.status]}
                        icon={order.status === 'cancelled' ? XCircle : true}
                      >
                        {ORDER_STATUS_LABEL[order.status]}
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
