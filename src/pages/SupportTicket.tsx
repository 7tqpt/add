import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, Lock, Send, UserCheck } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
  Spinner,
  Toast,
} from '@/components/ui/Feedback'
import { Field, Select, Textarea } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { listAdmins } from '@/services/admins'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDateTime, formatRelative } from '@/lib/format'
import type { TicketPriority, TicketStatus } from '@/lib/types'
import {
  TICKET_CATEGORY_LABEL,
  TICKET_PRIORITY_LABEL,
  TICKET_STATUS_LABEL,
  assignTicket,
  getTicket,
  listTicketMessages,
  replyToTicket,
  setTicketPriority,
  setTicketStatus,
} from '@/services/support'
import { TICKET_PRIORITY_TONE, TICKET_STATUS_TONE } from './Support'

const AUTHOR_LABEL: Record<'customer' | 'provider' | 'admin', string> = {
  customer: 'العميل',
  provider: 'مقدّم الخدمة',
  admin: 'الإدارة',
}

export function SupportTicketPage() {
  const { id = '' } = useParams()
  const { canWrite, user } = useAuth()
  const [reply, setReply] = useState('')
  const [internal, setInternal] = useState(false)
  const [nextStatus, setNextStatus] = useState<TicketStatus>('waiting_customer')
  const [sending, setSending] = useState(false)
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState<string | null>(null)

  const loadTicket = useCallback(() => getTicket(id), [id])
  const loadMessages = useCallback(() => listTicketMessages(id), [id])
  const loadAdmins = useCallback(() => listAdmins(), [])
  const ticket = useAsync(loadTicket, [id])
  const messages = useAsync(loadMessages, [id])
  const admins = useAsync(loadAdmins, [])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function send() {
    const record = ticket.data
    if (!record || reply.trim().length === 0) return
    setSending(true)
    try {
      await replyToTicket(record, reply.trim(), {
        internal,
        newStatus: internal ? undefined : nextStatus,
      })
      setReply('')
      setToast(internal ? 'أُضيفت الملاحظة الداخلية.' : 'أُرسل الرد ووصل صاحب التذكرة إشعار.')
      messages.reload()
      ticket.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر إرسال الرد.')
    } finally {
      setSending(false)
    }
  }

  async function changeStatus(status: TicketStatus) {
    const record = ticket.data
    if (!record) return
    setBusy(true)
    try {
      await setTicketStatus(record, status)
      setToast(`الحالة الآن «${TICKET_STATUS_LABEL[status]}».`)
      ticket.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث الحالة.')
    } finally {
      setBusy(false)
    }
  }

  async function changeAssignee(email: string) {
    const record = ticket.data
    if (!record) return
    setBusy(true)
    try {
      await assignTicket(record, email)
      setToast(email ? `أُسندت إلى ${email}.` : 'رُفع الإسناد.')
      ticket.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تغيير الإسناد.')
    } finally {
      setBusy(false)
    }
  }

  async function changePriority(priority: TicketPriority) {
    const record = ticket.data
    if (!record) return
    setBusy(true)
    try {
      await setTicketPriority(record, priority)
      setToast(`الأولوية الآن «${TICKET_PRIORITY_LABEL[priority]}».`)
      ticket.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث الأولوية.')
    } finally {
      setBusy(false)
    }
  }

  if (ticket.loading) return <LoadingBlock />
  if (ticket.error && !ticket.data) {
    return <ErrorState message={ticket.error} onRetry={ticket.reload} />
  }
  if (!ticket.data) {
    return (
      <Card>
        <EmptyState
          title="التذكرة غير موجودة"
          description="ربما حُذفت أو أن الرابط غير صحيح."
          action={
            <Link
              to="/support"
              className="text-sm font-medium text-accent underline underline-offset-4"
            >
              العودة إلى التذاكر
            </Link>
          }
        />
      </Card>
    )
  }

  const record = ticket.data
  const closed = record.status === 'closed'
  const thread = messages.data ?? []

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/support"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        {/* Under RTL "back" points toward the start edge, which is the right. */}
        <ArrowRight size={14} aria-hidden />
        كل التذاكر
      </Link>

      <Card>
        <CardHeader
          title={record.subject}
          subtitle={
            <span dir="auto">
              <span dir="ltr" className="tnum">
                {record.reference}
              </span>
              {' · '}
              {record.requester_name} ({record.opened_by === 'provider' ? 'مقدّم خدمة' : 'عميل'})
              {' · '}
              {TICKET_CATEGORY_LABEL[record.category]}
            </span>
          }
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={TICKET_STATUS_TONE[record.status]}>
                {TICKET_STATUS_LABEL[record.status]}
              </Badge>
              {record.priority !== 'normal' ? (
                <Badge tone={TICKET_PRIORITY_TONE[record.priority]}>
                  {TICKET_PRIORITY_LABEL[record.priority]}
                </Badge>
              ) : null}
            </div>
          }
        />

        <CardBody className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Fact label="فُتحت" value={formatRelative(record.created_at)} />
          <Fact
            label="أول ردّ"
            value={record.first_response_at ? formatRelative(record.first_response_at) : 'لم يُردّ بعد'}
          />
          <Fact label="آخر حركة" value={formatRelative(record.last_message_at)} />
          <Fact
            label="الحجز المرتبط"
            value={
              record.booking_id && record.booking_reference ? (
                <Link
                  to={`/bookings/${record.booking_id}`}
                  dir="ltr"
                  className="tnum text-accent underline-offset-4 hover:underline"
                >
                  {record.booking_reference}
                </Link>
              ) : (
                'لا يوجد'
              )
            }
          />
        </CardBody>

        <CardBody className="flex flex-wrap items-end gap-3 border-t border-hairline">
          <div className="w-44">
            <Field label="الحالة">
              {(fieldId) => (
                <Select
                  id={fieldId}
                  value={record.status}
                  disabled={busy || !canWrite}
                  onChange={(event) => changeStatus(event.target.value as TicketStatus)}
                >
                  {(Object.keys(TICKET_STATUS_LABEL) as TicketStatus[]).map((key) => (
                    <option key={key} value={key}>
                      {TICKET_STATUS_LABEL[key]}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          <div className="w-44">
            <Field label="الأولوية">
              {(fieldId) => (
                <Select
                  id={fieldId}
                  value={record.priority}
                  disabled={busy || !canWrite}
                  onChange={(event) => changePriority(event.target.value as TicketPriority)}
                >
                  {(Object.keys(TICKET_PRIORITY_LABEL) as TicketPriority[]).map((key) => (
                    <option key={key} value={key}>
                      {TICKET_PRIORITY_LABEL[key]}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          <div className="w-56">
            <Field label="المسؤول عنها">
              {(fieldId) => (
                <Select
                  id={fieldId}
                  value={record.assigned_to}
                  disabled={busy || !canWrite}
                  onChange={(event) => changeAssignee(event.target.value)}
                >
                  <option value="">غير مُسندة</option>
                  {/*
                    البريد الحالي يُدرج ولو لم يظهر في قائمة المسؤولين بعد —
                    وإلا اختفى الإسناد القائم من القائمة وبدا كأنه رُفع.
                  */}
                  {[
                    ...new Set([
                      ...(admins.data ?? []).map((a) => a.email),
                      ...(record.assigned_to ? [record.assigned_to] : []),
                    ]),
                  ].map((email) => (
                    <option key={email} value={email}>
                      {email}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>

          {canWrite && user && record.assigned_to !== user.email ? (
            <Button size="sm" disabled={busy} onClick={() => changeAssignee(user.email)}>
              <UserCheck size={14} aria-hidden />
              أسندها لي
            </Button>
          ) : null}

          {!canWrite ? (
            <p className="text-xs text-muted">دورك الحالي للقراءة فقط.</p>
          ) : null}
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="المحادثة" subtitle="ما يظهر لصاحب التذكرة في تطبيقه، عدا الملاحظات الداخلية" />
        {messages.loading ? (
          <LoadingBlock />
        ) : messages.error && !messages.data ? (
          <ErrorState message={messages.error} onRetry={messages.reload} />
        ) : (
          <CardBody className="flex flex-col gap-3">
            {thread.length === 0 ? (
              <p className="py-4 text-center text-xs text-muted">لا توجد رسائل بعد.</p>
            ) : (
              <ul className="flex flex-col gap-3">
                {thread.map((message) => (
                  <li
                    key={message.id}
                    className={cn(
                      'max-w-[46rem] rounded-lg border px-3 py-2.5 text-xs',
                      message.is_internal
                        ? // الملاحظة الداخلية تُميَّز بصرياً بوضوح: المسؤول الذي
                          // يظنّها ردّاً على العميل يترك العميل بلا جواب.
                          'ms-auto border-dashed border-[color-mix(in_oklab,var(--warning)_55%,transparent)] bg-[color-mix(in_oklab,var(--warning)_10%,transparent)]'
                        : message.author === 'admin'
                          ? 'ms-auto border-transparent bg-surface-2'
                          : 'border-hairline',
                    )}
                  >
                    <div className="flex items-center justify-between gap-3">
                      <span className="font-medium text-ink">
                        {message.author_name}
                        <span className="ms-1.5 font-normal text-muted">
                          ({AUTHOR_LABEL[message.author]})
                        </span>
                      </span>
                      <span className="tnum shrink-0 text-[11px] text-muted">
                        {formatDateTime(message.created_at)}
                      </span>
                    </div>
                    {message.is_internal ? (
                      <p className="mt-1 flex items-center gap-1 text-[11px] font-medium text-[var(--text-primary)]">
                        <Lock size={11} aria-hidden />
                        ملاحظة داخلية — لا يراها صاحب التذكرة
                      </p>
                    ) : null}
                    <p className="mt-1 leading-6 text-ink-2">{message.body}</p>
                  </li>
                ))}
              </ul>
            )}

            {closed ? (
              <p className="border-t border-hairline pt-3 text-xs text-muted">
                التذكرة مغلقة. غيّر الحالة أعلاه لإعادة فتحها والرد.
              </p>
            ) : (
              <div className="flex flex-col gap-2 border-t border-hairline pt-3">
                <Field
                  label={internal ? 'ملاحظة داخلية' : 'رد الإدارة'}
                  hint={
                    internal
                      ? 'تبقى بين المسؤولين — لا تصل صاحب التذكرة ولا تغيّر الحالة.'
                      : 'تصل صاحب التذكرة في تطبيقه مع إشعار.'
                  }
                >
                  {(fieldId) => (
                    <Textarea
                      id={fieldId}
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                      placeholder={
                        internal
                          ? 'ما تحتاج الإدارة تذكّره عن هذه التذكرة…'
                          : 'اكتب رداً واضحاً يشرح الخطوة التالية…'
                      }
                      disabled={!canWrite}
                    />
                  )}
                </Field>

                <div className="flex flex-wrap items-center gap-3">
                  <Button
                    size="sm"
                    variant="primary"
                    disabled={sending || !canWrite || reply.trim().length === 0}
                    title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                    onClick={send}
                  >
                    {sending ? <Spinner /> : <Send size={14} aria-hidden />}
                    {internal ? 'حفظ الملاحظة' : 'إرسال'}
                  </Button>

                  <label className="flex cursor-pointer items-center gap-1.5 text-xs text-ink-2">
                    <input
                      type="checkbox"
                      checked={internal}
                      disabled={!canWrite}
                      onChange={(event) => setInternal(event.target.checked)}
                      className="size-3.5 cursor-pointer accent-[var(--accent)]"
                    />
                    ملاحظة داخلية
                  </label>

                  {!internal ? (
                    <label className="flex items-center gap-1.5 text-xs whitespace-nowrap text-muted">
                      بعد الإرسال:
                      <Select
                        value={nextStatus}
                        disabled={!canWrite}
                        onChange={(event) => setNextStatus(event.target.value as TicketStatus)}
                        className="h-8 w-36 text-xs"
                        aria-label="الحالة بعد الإرسال"
                      >
                        {(['waiting_customer', 'in_progress', 'resolved'] as TicketStatus[]).map(
                          (key) => (
                            <option key={key} value={key}>
                              {TICKET_STATUS_LABEL[key]}
                            </option>
                          ),
                        )}
                      </Select>
                    </label>
                  ) : null}
                </div>
              </div>
            )}
          </CardBody>
        )}
      </Card>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <p className="text-[11px] text-muted">{label}</p>
      <p className="mt-0.5 text-xs font-medium text-ink">{value}</p>
    </div>
  )
}
