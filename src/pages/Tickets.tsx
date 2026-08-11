import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { Search, Send } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Input, Select, Textarea } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate, formatDateTime, formatRelative } from '@/lib/format'
import type { SupportTicket, TicketPriority, TicketStatus } from '@/lib/types'
import {
  TICKET_CATEGORY_LABEL,
  TICKET_PRIORITY_LABEL,
  TICKET_STATUS_LABEL,
  listTicketMessages,
  listTickets,
  replyToTicket,
  setTicketPriority,
  setTicketStatus,
} from '@/services/tickets'

const PAGE_SIZE = 8
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<TicketStatus, Tone> = {
  open: 'critical',
  pending: 'warning',
  resolved: 'good',
  closed: 'neutral',
}

const PRIORITY_TONE: Record<TicketPriority, Tone> = {
  urgent: 'critical',
  high: 'serious',
  normal: 'neutral',
  low: 'neutral',
}

export function TicketsPage() {
  const [status, setStatus] = useState<TicketStatus | 'all'>('all')
  const [priority, setPriority] = useState<TicketPriority | 'all'>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, priority])

  const load = useCallback(
    () => listTickets({ status, priority, search: debouncedSearch, page, pageSize: PAGE_SIZE }),
    [status, priority, debouncedSearch, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    status,
    priority,
    debouncedSearch,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  // Keep a selection that still exists in the current result set; otherwise fall
  // back to the first row so the detail pane is never stranded on a filtered-out
  // ticket.
  const rows = data?.rows ?? []
  const selected = rows.find((ticket) => ticket.id === selectedId) ?? rows[0] ?? null

  const buildExport = useCallback(async () => {
    const all = await listTickets({
      status,
      priority,
      search: debouncedSearch,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: ['الموضوع', 'المستخدم', 'البريد', 'التصنيف', 'الحالة', 'الأولوية', 'تاريخ الفتح', 'آخر تحديث'],
      rows: all.rows.map((ticket) => [
        ticket.subject,
        ticket.user_name,
        ticket.user_email,
        TICKET_CATEGORY_LABEL[ticket.category],
        TICKET_STATUS_LABEL[ticket.status],
        TICKET_PRIORITY_LABEL[ticket.priority],
        formatDate(ticket.created_at),
        formatDate(ticket.updated_at),
      ]),
    }
  }, [status, priority, debouncedSearch])

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
            placeholder="ابحث في الموضوع أو اسم المستخدم…"
            aria-label="بحث في البلاغات"
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

        <div className="w-36">
          <Select
            value={priority}
            onChange={(event) => setPriority(event.target.value as TicketPriority | 'all')}
            aria-label="تصفية حسب الأولوية"
          >
            <option value="all">كل الأولويات</option>
            {(Object.keys(TICKET_PRIORITY_LABEL) as TicketPriority[]).map((key) => (
              <option key={key} value={key}>
                {TICKET_PRIORITY_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-البلاغات"
          build={buildExport}
          disabled={!data || data.total === 0}
          onError={setToast}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-5">
        <div className="xl:col-span-2">
          <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
            {loading ? (
              <LoadingBlock />
            ) : error && !data ? (
              <ErrorState message={error} onRetry={reload} />
            ) : rows.length === 0 ? (
              <EmptyState title="لا توجد بلاغات" description="جرّب تغيير عوامل التصفية." />
            ) : (
              <ul className="divide-y divide-[var(--border)]">
                {rows.map((ticket) => (
                  <li key={ticket.id}>
                    <button
                      type="button"
                      onClick={() => setSelectedId(ticket.id)}
                      aria-current={selected?.id === ticket.id}
                      className={cn(
                        'flex w-full cursor-pointer flex-col gap-1.5 px-4 py-3 text-start transition-colors sm:px-5',
                        selected?.id === ticket.id ? 'bg-surface-2' : 'hover:bg-surface-2',
                      )}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <p className="line-clamp-2 text-sm font-medium text-ink">{ticket.subject}</p>
                        <Badge tone={STATUS_TONE[ticket.status]}>
                          {TICKET_STATUS_LABEL[ticket.status]}
                        </Badge>
                      </div>
                      <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-muted">
                        <span>{ticket.user_name}</span>
                        <span>{TICKET_CATEGORY_LABEL[ticket.category]}</span>
                        <span>{formatRelative(ticket.created_at)}</span>
                      </div>
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {rows.length > 0 && data ? (
              <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
            ) : null}
          </Card>
        </div>

        <div className="xl:col-span-3">
          {selected ? (
            <TicketDetail
              key={selected.id}
              ticket={selected}
              onChanged={reload}
              onToast={setToast}
            />
          ) : (
            <Card>
              <EmptyState title="اختر بلاغاً" description="اختر بلاغاً من القائمة لعرض المحادثة." />
            </Card>
          )}
        </div>
      </div>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function TicketDetail({
  ticket,
  onChanged,
  onToast,
}: {
  ticket: SupportTicket
  onChanged: () => void
  onToast: (message: string) => void
}) {
  const { user, canWrite } = useAuth()
  const load = useCallback(() => listTicketMessages(ticket.id), [ticket.id])
  const { data, error, loading, reload } = useAsync(load, [ticket.id])

  const [reply, setReply] = useState('')
  const [sending, setSending] = useState(false)
  const [busy, setBusy] = useState(false)

  async function change(action: () => Promise<void>, message: string) {
    setBusy(true)
    try {
      await action()
      onToast(message)
      onChanged()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر حفظ التغيير.')
    } finally {
      setBusy(false)
    }
  }

  async function handleReply(event: FormEvent) {
    event.preventDefault()
    const body = reply.trim()
    if (!body) return

    setSending(true)
    try {
      await replyToTicket(ticket, body, user?.email ?? '')
      setReply('')
      onToast('تم إرسال الرد.')
      reload()
      onChanged()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر إرسال الرد.')
    } finally {
      setSending(false)
    }
  }

  return (
    <Card>
      <CardHeader
        title={ticket.subject}
        subtitle={`${ticket.user_name} · ${ticket.user_email}`}
        actions={<Badge tone={PRIORITY_TONE[ticket.priority]}>{TICKET_PRIORITY_LABEL[ticket.priority]}</Badge>}
      />

      <CardBody className="flex flex-col gap-4">
        <div className="flex flex-wrap items-end gap-3">
          <div className="w-40">
            <label htmlFor={`status-${ticket.id}`} className="mb-1.5 block text-xs font-medium text-ink-2">
              الحالة
            </label>
            <Select
              id={`status-${ticket.id}`}
              value={ticket.status}
              disabled={busy || !canWrite}
              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
              onChange={(event) =>
                change(
                  () => setTicketStatus(ticket, event.target.value as TicketStatus),
                  'تم تحديث حالة البلاغ.',
                )
              }
            >
              {(Object.keys(TICKET_STATUS_LABEL) as TicketStatus[]).map((key) => (
                <option key={key} value={key}>
                  {TICKET_STATUS_LABEL[key]}
                </option>
              ))}
            </Select>
          </div>

          <div className="w-36">
            <label htmlFor={`priority-${ticket.id}`} className="mb-1.5 block text-xs font-medium text-ink-2">
              الأولوية
            </label>
            <Select
              id={`priority-${ticket.id}`}
              value={ticket.priority}
              disabled={busy || !canWrite}
              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
              onChange={(event) =>
                change(
                  () => setTicketPriority(ticket, event.target.value as TicketPriority),
                  'تم تحديث أولوية البلاغ.',
                )
              }
            >
              {(Object.keys(TICKET_PRIORITY_LABEL) as TicketPriority[]).map((key) => (
                <option key={key} value={key}>
                  {TICKET_PRIORITY_LABEL[key]}
                </option>
              ))}
            </Select>
          </div>

          {ticket.user_id ? (
            <Link
              to={`/users/${ticket.user_id}`}
              className="pb-2.5 text-xs font-medium text-series-1 underline underline-offset-4"
            >
              عرض ملف المستخدم
            </Link>
          ) : null}
        </div>

        <div className="flex flex-col gap-3 border-t border-hairline pt-4">
          {loading ? (
            <LoadingBlock label="جارٍ تحميل المحادثة…" />
          ) : error ? (
            <ErrorState message={error} onRetry={reload} />
          ) : (
            (data ?? []).map((message) => (
              <article
                key={message.id}
                className={cn(
                  'max-w-[85%] rounded-xl border px-3.5 py-2.5',
                  message.author === 'admin'
                    ? 'self-start border-transparent bg-surface-2'
                    : 'self-end border-hairline bg-surface',
                )}
              >
                <p className="text-[11px] text-muted">
                  {message.author === 'admin' ? 'فريق الدعم' : ticket.user_name}
                  {message.author_email ? ` · ${message.author_email}` : ''}
                </p>
                <p className="mt-1 text-xs leading-6 text-ink">{message.body}</p>
                <p className="tnum mt-1.5 text-[11px] text-muted">
                  {formatDateTime(message.created_at)}
                </p>
              </article>
            ))
          )}
        </div>

        <form onSubmit={handleReply} className="flex flex-col gap-2 border-t border-hairline pt-4">
          <label htmlFor={`reply-${ticket.id}`} className="text-xs font-medium text-ink-2">
            الرد على المستخدم
          </label>
          <Textarea
            id={`reply-${ticket.id}`}
            value={reply}
            disabled={!canWrite}
            onChange={(event) => setReply(event.target.value)}
            placeholder={canWrite ? 'اكتب ردك هنا…' : 'دورك الحالي للقراءة فقط'}
          />
          <Button
            type="submit"
            variant="primary"
            size="sm"
            className="w-fit"
            disabled={sending || !canWrite || reply.trim().length === 0}
          >
            {sending ? <Spinner /> : <Send size={14} aria-hidden />}
            إرسال الرد
          </Button>
        </form>
      </CardBody>
    </Card>
  )
}
