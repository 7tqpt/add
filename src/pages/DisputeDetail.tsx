import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, Gavel, Send } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatDateTime, formatMoney } from '@/lib/format'
import type { DisputeStatus } from '@/lib/types'
import {
  DISPUTE_CATEGORY_LABEL,
  DISPUTE_PARTY_LABEL,
  DISPUTE_STATUS_LABEL,
  getDispute,
  listDisputeMessages,
  replyToDispute,
  resolveDispute,
} from '@/services/trust'
import { getBooking } from '@/services/bookings'
import { DISPUTE_STATUS_TONE } from './Disputes'

export function DisputeDetailPage() {
  const { id = '' } = useParams()
  const { user, canWrite } = useAuth()
  const [toast, setToast] = useState<string | null>(null)
  const [reply, setReply] = useState('')
  const [sending, setSending] = useState(false)
  const [deciding, setDeciding] = useState(false)
  const [busy, setBusy] = useState(false)
  const [decision, setDecision] = useState<DisputeStatus>('resolved')
  const [resolution, setResolution] = useState('')
  const [refund, setRefund] = useState('0')

  const loadDispute = useCallback(() => getDispute(id), [id])
  const loadMessages = useCallback(() => listDisputeMessages(id), [id])

  const dispute = useAsync(loadDispute, [id])
  const messages = useAsync(loadMessages, [id])

  const bookingId = dispute.data?.booking_id ?? ''
  const loadBooking = useCallback(
    () => (bookingId ? getBooking(bookingId) : Promise.resolve(null)),
    [bookingId],
  )
  const booking = useAsync(loadBooking, [bookingId])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2800)
    return () => clearTimeout(timer)
  }, [toast])

  if (dispute.loading) return <LoadingBlock />
  if (dispute.error && !dispute.data) {
    return <ErrorState message={dispute.error} onRetry={dispute.reload} />
  }
  if (!dispute.data) {
    return (
      <Card>
        <EmptyState
          title="النزاع غير موجود"
          description="ربما أُغلق النزاع أو أن الرابط غير صحيح."
          action={
            <Link
              to="/disputes"
              className="text-sm font-medium text-accent underline underline-offset-4"
            >
              العودة إلى النزاعات
            </Link>
          }
        />
      </Card>
    )
  }

  const record = dispute.data
  const settled = record.status === 'resolved' || record.status === 'closed'
  // The refund can never exceed what the customer actually paid.
  const maxRefund = booking.data?.paid_amount ?? 0

  async function send() {
    const body = reply.trim()
    if (!body) return
    setSending(true)
    try {
      await replyToDispute(record, body, user?.email ?? 'الإدارة')
      setReply('')
      setToast('أُرسل الرد إلى طرفَي النزاع.')
      messages.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر إرسال الرد.')
    } finally {
      setSending(false)
    }
  }

  async function decide() {
    setBusy(true)
    try {
      const amount = Math.max(0, Math.min(maxRefund, Number(refund) || 0))
      await resolveDispute(record, decision, resolution.trim(), amount, user?.email ?? 'الإدارة')
      setToast(`تم نقل النزاع إلى «${DISPUTE_STATUS_LABEL[decision]}».`)
      dispute.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر حسم النزاع.')
    } finally {
      setBusy(false)
      setDeciding(false)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/disputes"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        <ArrowRight size={14} aria-hidden />
        كل النزاعات
      </Link>

      <Card>
        <CardHeader
          title={record.subject}
          subtitle={
            <span dir="ltr" className="tnum block text-start">
              {record.reference}
            </span>
          }
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={DISPUTE_STATUS_TONE[record.status]}>
                {DISPUTE_STATUS_LABEL[record.status]}
              </Badge>
              {!settled ? (
                <Button
                  size="sm"
                  variant="primary"
                  disabled={!canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() => {
                    setDecision('resolved')
                    setRefund('0')
                    setDeciding(true)
                  }}
                >
                  <Gavel size={14} aria-hidden />
                  حسم النزاع
                </Button>
              ) : null}
            </div>
          }
        />
        <CardBody className="flex flex-col gap-4">
          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-5">
            <Detail
              label="الحجز"
              node={
                <Link
                  to={`/bookings/${record.booking_id}`}
                  dir="ltr"
                  className="tnum block text-start underline-offset-4 hover:text-accent hover:underline"
                >
                  {record.booking_reference}
                </Link>
              }
            />
            <Detail
              label="العميل"
              node={
                <Link
                  to={`/users/${record.user_id}`}
                  className="underline-offset-4 hover:text-accent hover:underline"
                >
                  {record.user_name}
                </Link>
              }
            />
            <Detail
              label="مقدّم الخدمة"
              node={
                <Link
                  to={`/providers/${record.provider_id}`}
                  className="underline-offset-4 hover:text-accent hover:underline"
                >
                  {record.provider_name}
                </Link>
              }
            />
            <Detail label="التصنيف" value={DISPUTE_CATEGORY_LABEL[record.category]} />
            <Detail
              label="فتح النزاع"
              value={`${DISPUTE_PARTY_LABEL[record.opened_by]} · ${formatDate(record.created_at)}`}
            />
          </dl>

          <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs leading-6 text-ink-2">
            {record.description}
          </p>

          {settled ? (
            <div className="rounded-lg border border-[color-mix(in_oklab,var(--good)_35%,transparent)] px-3 py-2.5 text-xs">
              <p className="font-medium text-ink">قرار الإدارة</p>
              <p className="mt-1 leading-6 text-ink-2">{record.resolution || '—'}</p>
              <p className="mt-1.5 text-muted">
                {record.refund_amount > 0
                  ? `أُعيد للعميل ${formatMoney(record.refund_amount)}`
                  : 'دون إعادة مبالغ'}
                {record.resolved_by ? ` · ${record.resolved_by}` : ''}
                {record.resolved_at ? ` · ${formatDate(record.resolved_at)}` : ''}
              </p>
            </div>
          ) : null}
        </CardBody>
      </Card>

      <Card className={cn(messages.refetching && 'is-refetching')}>
        <CardHeader title="المحادثة" subtitle="ما تبادله الطرفان والإدارة حول هذا النزاع" />
        {messages.loading ? (
          <LoadingBlock />
        ) : messages.error && !messages.data ? (
          <ErrorState message={messages.error} onRetry={messages.reload} />
        ) : (
          <CardBody className="flex flex-col gap-3">
            {(messages.data ?? []).length === 0 ? (
              <p className="py-4 text-center text-xs text-muted">لا توجد رسائل بعد.</p>
            ) : (
              <ul className="flex flex-col gap-3">
                {(messages.data ?? []).map((message) => (
                  <li
                    key={message.id}
                    className={cn(
                      'max-w-[46rem] rounded-lg border px-3 py-2.5 text-xs',
                      message.author === 'admin'
                        ? 'border-transparent bg-surface-2 ms-auto'
                        : 'border-hairline',
                    )}
                  >
                    <div className="flex items-center justify-between gap-3">
                      <span className="font-medium text-ink">
                        {message.author_name}
                        <span className="ms-1.5 font-normal text-muted">
                          ({DISPUTE_PARTY_LABEL[message.author]})
                        </span>
                      </span>
                      <span className="tnum shrink-0 text-[11px] text-muted">
                        {formatDateTime(message.created_at)}
                      </span>
                    </div>
                    <p className="mt-1 leading-6 text-ink-2">{message.body}</p>
                  </li>
                ))}
              </ul>
            )}

            {!settled ? (
              <div className="flex flex-col gap-2 border-t border-hairline pt-3">
                <Field label="رد الإدارة" hint="يصل الطرفين معاً في التطبيق.">
                  {(fieldId) => (
                    <Textarea
                      id={fieldId}
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                      placeholder="اكتب رداً واضحاً يشرح الخطوة التالية…"
                      disabled={!canWrite}
                    />
                  )}
                </Field>
                <Button
                  size="sm"
                  variant="primary"
                  className="w-fit"
                  disabled={sending || !canWrite || reply.trim().length === 0}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={send}
                >
                  {sending ? <Spinner /> : <Send size={14} aria-hidden />}
                  إرسال
                </Button>
              </div>
            ) : null}
          </CardBody>
        )}
      </Card>

      <ConfirmDialog
        open={deciding}
        title="حسم النزاع"
        message={
          maxRefund > 0
            ? `أقصى مبلغ يمكن إعادته هو ${formatMoney(maxRefund)} — وهو ما دفعه العميل فعلاً. الاسترجاع الفعلي يُنفَّذ بعدها من شاشة عمليات الدفع.`
            : 'لم يُسجَّل دفع على هذا الحجز، فالحسم يقتصر على القرار المكتوب.'
        }
        confirmLabel="تسجيل القرار"
        tone="primary"
        busy={busy}
        onConfirm={decide}
        onCancel={() => setDeciding(false)}
      >
        <Field label="القرار">
          {(fieldId) => (
            <Select
              id={fieldId}
              value={decision}
              onChange={(event) => setDecision(event.target.value as DisputeStatus)}
            >
              <option value="investigating">فتح تحقيق</option>
              <option value="resolved">محسوم لصالح أحد الطرفين</option>
              <option value="closed">إغلاق دون إجراء</option>
            </Select>
          )}
        </Field>

        <Field label="نص القرار" hint="يظهر للطرفين وفي سجل العمليات.">
          {(fieldId) => (
            <Textarea
              id={fieldId}
              value={resolution}
              onChange={(event) => setResolution(event.target.value)}
              placeholder="مثال: ثبت عدم حضور مقدّم الخدمة، ويُعاد كامل المبلغ للعميل."
            />
          )}
        </Field>

        {decision === 'resolved' && maxRefund > 0 ? (
          <Field label="المبلغ المعاد للعميل" hint={`الحد الأقصى ${formatMoney(maxRefund)}.`}>
            {(fieldId) => (
              <Input
                id={fieldId}
                type="number"
                min={0}
                max={maxRefund}
                value={refund}
                onChange={(event) => setRefund(event.target.value)}
                dir="ltr"
                className="tnum text-start"
              />
            )}
          </Field>
        ) : null}
      </ConfirmDialog>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function Detail({ label, value, node }: { label: string; value?: string; node?: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-muted">{label}</dt>
      <dd className="mt-0.5 truncate font-medium text-ink">{node ?? value}</dd>
    </div>
  )
}
