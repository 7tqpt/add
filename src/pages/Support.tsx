import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Clock, Inbox, MailQuestion, Search } from 'lucide-react'
import { StatTile } from '@/components/charts/StatTile'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatCount, formatDate, formatNumber, formatRelative, HOUR_FORMS } from '@/lib/format'
import type { TicketCategory, TicketPriority, TicketStatus } from '@/lib/types'
import {
  TICKET_CATEGORY_LABEL,
  TICKET_PRIORITY_LABEL,
  TICKET_STATUS_LABEL,
  getTicketStats,
  listTickets,
} from '@/services/support'

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

export const TICKET_STATUS_TONE: Record<TicketStatus, Tone> = {
  open: 'critical',
  in_progress: 'warning',
  waiting_customer: 'serious',
  resolved: 'good',
  closed: 'neutral',
}

export const TICKET_PRIORITY_TONE: Record<TicketPriority, Tone> = {
  normal: 'neutral',
  high: 'warning',
  urgent: 'critical',
}

export function SupportPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<TicketStatus | 'all'>('all')
  const [category, setCategory] = useState<TicketCategory | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, category])

  const load = useCallback(
    () => listTickets({ search: debouncedSearch, status, category, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, category, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    category,
    page,
  ])

  // مستقلّة عن التصفية عمداً: «كم ينتظرنا» سؤال عن الصندوق كلّه لا عن الشاشة.
  const loadStats = useCallback(() => getTicketStats(), [])
  const stats = useAsync(loadStats, [])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listTickets({
      search: debouncedSearch,
      status,
      category,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'رقم التذكرة',
        'الموضوع',
        'التصنيف',
        'مقدّمها',
        'من',
        'الأولوية',
        'الحالة',
        'عدد الرسائل',
        'تاريخ الفتح',
        'أول ردّ',
        'آخر حركة',
      ],
      rows: all.rows.map((ticket) => [
        ticket.reference,
        ticket.subject,
        TICKET_CATEGORY_LABEL[ticket.category],
        ticket.requester_name,
        ticket.opened_by === 'provider' ? 'مقدّم خدمة' : 'عميل',
        TICKET_PRIORITY_LABEL[ticket.priority],
        TICKET_STATUS_LABEL[ticket.status],
        ticket.messages_count,
        formatDate(ticket.created_at),
        ticket.first_response_at ? formatDate(ticket.first_response_at) : '',
        formatDate(ticket.last_message_at),
      ]),
    }
  }, [debouncedSearch, status, category])

  const median = stats.data?.medianFirstResponseHours ?? null

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatTile
          label="ينتظر ردّ الإدارة"
          value={formatNumber(stats.data?.waitingOnUs ?? 0)}
          icon={Inbox}
          refetching={stats.refetching}
        />
        <StatTile
          label="لم يُردّ عليها بعد"
          value={formatNumber(stats.data?.neverAnswered ?? 0)}
          icon={MailQuestion}
          refetching={stats.refetching}
        />
        <StatTile
          label="وسيط زمن أول ردّ"
          value={median === null ? '—' : formatCount(Math.round(median), HOUR_FORMS)}
          icon={Clock}
          refetching={stats.refetching}
        />
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
            placeholder="ابحث برقم التذكرة أو الموضوع أو اسم صاحبها…"
            aria-label="بحث في التذاكر"
            className="ps-9"
          />
        </div>

        <div className="w-40">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as TicketStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(TICKET_STATUS_LABEL) as TicketStatus[]).map((key) => (
              <option key={key} value={key}>
                {TICKET_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value as TicketCategory | 'all')}
            aria-label="تصفية حسب التصنيف"
          >
            <option value="all">كل التصنيفات</option>
            {(Object.keys(TICKET_CATEGORY_LABEL) as TicketCategory[]).map((key) => (
              <option key={key} value={key}>
                {TICKET_CATEGORY_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-خدمة-العملاء"
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
            title="لا توجد تذاكر"
            description="جرّب تعديل البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {['التذكرة', 'صاحبها', 'التصنيف', 'الأولوية', 'آخر حركة', 'الحالة'].map(
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
                {data.rows.map((ticket) => (
                  <tr
                    key={ticket.id}
                    className="border-b border-hairline last:border-0 hover:bg-surface-2"
                  >
                    <td className="px-4 py-3">
                      <Link
                        to={`/support/${ticket.id}`}
                        className="text-xs font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                      >
                        {ticket.subject}
                      </Link>
                      <p dir="ltr" className="tnum text-start text-[11px] text-muted">
                        {ticket.reference}
                      </p>
                      {/* من يملكها أهمّ سؤال في صندوق دعم — «غير مُسندة» جواب
                          يستحق الظهور بقدر ما يستحقه الاسم. */}
                      <p className="text-[11px] text-muted">
                        {ticket.assigned_to ? (
                          <span dir="ltr">{ticket.assigned_to}</span>
                        ) : (
                          <span className="text-[var(--critical)]">غير مُسندة</span>
                        )}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {ticket.requester_name}
                      <span className="block text-[11px] text-muted">
                        {ticket.opened_by === 'provider' ? 'مقدّم خدمة' : 'عميل'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {TICKET_CATEGORY_LABEL[ticket.category]}
                    </td>
                    <td className="px-4 py-3">
                      {ticket.priority === 'normal' ? (
                        <span className="text-xs text-muted">—</span>
                      ) : (
                        <Badge tone={TICKET_PRIORITY_TONE[ticket.priority]}>
                          {TICKET_PRIORITY_LABEL[ticket.priority]}
                        </Badge>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-muted">
                      {formatRelative(ticket.last_message_at)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone={TICKET_STATUS_TONE[ticket.status]}>
                        {TICKET_STATUS_LABEL[ticket.status]}
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
