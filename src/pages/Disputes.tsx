import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney, formatRelative } from '@/lib/format'
import type { DisputeCategory, DisputeStatus } from '@/lib/types'
import {
  DISPUTE_CATEGORY_LABEL,
  DISPUTE_PARTY_LABEL,
  DISPUTE_STATUS_LABEL,
  listDisputes,
} from '@/services/trust'

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

export const DISPUTE_STATUS_TONE: Record<DisputeStatus, Tone> = {
  open: 'critical',
  investigating: 'warning',
  resolved: 'good',
  closed: 'neutral',
}

export function DisputesPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<DisputeStatus | 'all'>('all')
  const [category, setCategory] = useState<DisputeCategory | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, category])

  const load = useCallback(
    () => listDisputes({ search: debouncedSearch, status, category, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, category, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    category,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listDisputes({
      search: debouncedSearch,
      status,
      category,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'رقم النزاع',
        'الحجز',
        'الموضوع',
        'التصنيف',
        'فتحه',
        'العميل',
        'مقدّم الخدمة',
        'الحالة',
        'المبلغ المعاد',
        'تاريخ الفتح',
        'تاريخ الحسم',
      ],
      rows: all.rows.map((dispute) => [
        dispute.reference,
        dispute.booking_reference,
        dispute.subject,
        DISPUTE_CATEGORY_LABEL[dispute.category],
        DISPUTE_PARTY_LABEL[dispute.opened_by],
        dispute.user_name,
        dispute.provider_name,
        DISPUTE_STATUS_LABEL[dispute.status],
        dispute.refund_amount,
        formatDate(dispute.created_at),
        dispute.resolved_at ? formatDate(dispute.resolved_at) : '',
      ]),
    }
  }, [debouncedSearch, status, category])

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
            placeholder="ابحث برقم النزاع أو الموضوع أو أحد الطرفين…"
            aria-label="بحث في النزاعات"
            className="ps-9"
          />
        </div>

        <div className="w-40">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as DisputeStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(DISPUTE_STATUS_LABEL) as DisputeStatus[]).map((key) => (
              <option key={key} value={key}>
                {DISPUTE_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value as DisputeCategory | 'all')}
            aria-label="تصفية حسب التصنيف"
          >
            <option value="all">كل التصنيفات</option>
            {(Object.keys(DISPUTE_CATEGORY_LABEL) as DisputeCategory[]).map((key) => (
              <option key={key} value={key}>
                {DISPUTE_CATEGORY_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-النزاعات"
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
            title="لا توجد نزاعات"
            description="جرّب تعديل البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {['النزاع', 'الطرفان', 'التصنيف', 'فتحه', 'المبلغ المعاد', 'منذ', 'الحالة'].map(
                    (heading) => (
                      <th
                        key={heading}
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
                {data.rows.map((dispute) => (
                  <tr
                    key={dispute.id}
                    className="border-b border-hairline last:border-0 hover:bg-surface-2"
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/disputes/${dispute.id}`}
                        className="text-xs font-medium text-ink underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {dispute.subject}
                      </Link>
                      <p dir="ltr" className="tnum text-start text-[11px] text-muted">
                        {dispute.reference} · {dispute.booking_reference}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {dispute.user_name}
                      <span className="block text-[11px] text-muted">{dispute.provider_name}</span>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {DISPUTE_CATEGORY_LABEL[dispute.category]}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {DISPUTE_PARTY_LABEL[dispute.opened_by]}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {dispute.refund_amount > 0 ? formatMoney(dispute.refund_amount) : '—'}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-muted">
                      {formatRelative(dispute.created_at)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone={DISPUTE_STATUS_TONE[dispute.status]}>
                        {DISPUTE_STATUS_LABEL[dispute.status]}
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
