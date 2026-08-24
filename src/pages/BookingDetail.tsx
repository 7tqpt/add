import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, Ban, Check, CheckCircle2, MapPin, Users, XCircle } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Textarea } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatDateTime, formatMoney, formatNumber, formatTime } from '@/lib/format'
import type { BookingStatus, PaymentStatus } from '@/lib/types'
import {
  BOOKING_STATUS_LABEL,
  BOOKING_TRAIL,
  getBooking,
  listBookingPayments,
  refundableNow,
  setBookingStatus,
} from '@/services/bookings'
import { PAYMENT_KIND_LABEL, PAYMENT_METHOD_LABEL, PAYMENT_STATUS_LABEL } from '@/services/finance'
import { describeRule } from '@/services/catalog'
import { BOOKING_STATUS_TONE } from './Bookings'
import { errorText } from '@/services/base'

const PAYMENT_TONE: Record<PaymentStatus, Tone> = {
  paid: 'good',
  pending: 'warning',
  failed: 'critical',
  refunded: 'serious',
}

/** The states an admin may push a booking into, and what each one means here. */
type Intervention = { status: BookingStatus; label: string; title: string; message: string }

function interventionsFor(status: BookingStatus): Intervention[] {
  const list: Intervention[] = []

  if (status === 'pending_provider') {
    list.push({
      status: 'confirmed',
      label: 'تأكيد نيابةً عن مقدّم الخدمة',
      title: 'تأكيد الحجز؟',
      message:
        'يُستخدم هذا حين يتعذّر على مقدّم الخدمة الرد من التطبيق وقد أكّد الموعد خارجه. سيرى العميل الحجز مؤكداً فوراً.',
    })
  }

  if (status === 'confirmed') {
    list.push({
      status: 'completed',
      label: 'إغلاق كمنفّذ',
      title: 'إغلاق الحجز كمنفّذ؟',
      message:
        'سيُحتسب المبلغ ضمن مستحقات مقدّم الخدمة وتُفتح للعميل إمكانية التقييم. لا يمكن التراجع.',
    })
  }

  if (status === 'pending_provider' || status === 'confirmed') {
    list.push({
      status: 'cancelled',
      label: 'إلغاء',
      title: 'إلغاء الحجز؟',
      message:
        'يُحسب المبلغ المسترد وفق سلّم الإلغاء المنسوخ في هذا الحجز. الاسترجاع الفعلي يُنفَّذ من شاشة عمليات الدفع.',
    })
  }

  return list
}

export function BookingDetailPage() {
  const { id = '' } = useParams()
  const { can } = useAuth()
  const canWrite = can('bookings')
  const [toast, setToast] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [pending, setPending] = useState<Intervention | null>(null)
  const [reason, setReason] = useState('')

  const loadBooking = useCallback(() => getBooking(id), [id])
  const loadPayments = useCallback(() => listBookingPayments(id), [id])

  const booking = useAsync(loadBooking, [id])
  const payments = useAsync(loadPayments, [id])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2800)
    return () => clearTimeout(timer)
  }, [toast])

  async function run(action: () => Promise<void>, message: string) {
    setBusy(true)
    try {
      await action()
      setToast(message)
      booking.reload()
      payments.reload()
    } catch (cause) {
      setToast(errorText(cause, 'تعذّر تنفيذ الإجراء.'))
    } finally {
      setBusy(false)
      setPending(null)
      setReason('')
    }
  }

  if (booking.loading) return <LoadingBlock />
  if (booking.error && !booking.data) {
    return <ErrorState message={booking.error} onRetry={booking.reload} />
  }
  if (!booking.data) {
    return (
      <Card>
        <EmptyState
          title="الحجز غير موجود"
          description="ربما حُذف الحجز أو أن الرابط غير صحيح."
          action={
            <Link
              to="/bookings"
              className="text-sm font-medium text-accent underline underline-offset-4"
            >
              العودة إلى الحجوزات
            </Link>
          }
        />
      </Card>
    )
  }

  const record = booking.data
  const rows = payments.data ?? []
  const collected = rows
    .filter((payment) => payment.status === 'paid')
    .reduce((total, payment) => total + payment.amount, 0)
  const remaining = Math.max(0, record.total_price - record.paid_amount)
  const actions = interventionsFor(record.status)
  const refundable = refundableNow(record)

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/bookings"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        {/* Under RTL "back" points toward the start edge, which is the right. */}
        <ArrowRight size={14} aria-hidden />
        كل الحجوزات
      </Link>

      <Card>
        <CardHeader
          title={
            <span dir="ltr" className="tnum block text-start">
              {record.reference}
            </span>
          }
          subtitle={`${record.service_title} · ${record.category_name}`}
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Badge
                tone={BOOKING_STATUS_TONE[record.status]}
                icon={record.status === 'expired' ? XCircle : true}
              >
                {BOOKING_STATUS_LABEL[record.status]}
              </Badge>

              {actions.map((action) => (
                <Button
                  key={action.status}
                  size="sm"
                  variant={action.status === 'cancelled' ? 'ghost' : 'primary'}
                  disabled={busy || !canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() => setPending(action)}
                >
                  {action.status === 'cancelled' ? (
                    <Ban size={14} aria-hidden />
                  ) : (
                    <CheckCircle2 size={14} aria-hidden />
                  )}
                  {action.label}
                </Button>
              ))}
            </div>
          }
        />
        <CardBody className="flex flex-col gap-4">
          <BookingTrail status={record.status} />

          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-5">
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
            <Detail
              label="موعد المناسبة"
              value={`${formatDate(record.event_date)} · ${formatTime(record.event_time)}`}
            />
            <Detail label="تاريخ الحجز" value={formatDateTime(record.created_at)} />
            <Detail
              label="خطة العرس"
              node={
                record.plan_id ? (
                  <Link
                    to={`/plans/${record.plan_id}`}
                    className="underline-offset-4 hover:text-accent hover:underline"
                  >
                    عرض الخطة
                  </Link>
                ) : (
                  <span className="text-muted">حجز مستقل</span>
                )
              }
            />
          </dl>

          <div className="flex items-start gap-2 glass-item rounded-lg px-3 py-2.5">
            <MapPin size={14} aria-hidden className="mt-0.5 shrink-0 text-muted" />
            <div className="min-w-0 text-xs">
              <p className="text-ink">
                {record.governorate} — {record.address}
              </p>
              <p className="mt-1 flex items-center gap-1.5 text-muted">
                <Users size={12} aria-hidden />
                {formatNumber(record.guests_count)} مدعو
              </p>
              {record.notes ? <p className="mt-1 leading-6 text-ink-2">{record.notes}</p> : null}
            </div>
          </div>

          {record.status === 'cancelled' && record.cancel_reason ? (
            <Note text={`سبب الإلغاء: ${record.cancel_reason}`} at={record.cancelled_at} />
          ) : null}
          {record.status === 'rejected' && record.rejection_reason ? (
            <Note text={`سبب الاعتذار: ${record.rejection_reason}`} at={record.cancelled_at} />
          ) : null}
        </CardBody>
      </Card>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader title="الحساب" subtitle="ما اتُّفق عليه، وما دخل فعلاً" />
          <CardBody className="flex flex-col gap-4">
            <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-5">
              <Detail label="سعر الخدمة" value={formatMoney(record.total_price)} />
              <Detail label="العربون المطلوب" value={formatMoney(record.deposit_amount)} />
              <Detail label="المدفوع" value={formatMoney(record.paid_amount)} />
              <Detail label="المتبقي" value={formatMoney(remaining)} />
              <Detail
                label={`عمولة المنصة (${record.commission_percent}%)`}
                value={formatMoney(record.commission_amount)}
              />
            </dl>

            <div className="rounded-lg border border-hairline px-3 py-2.5 text-xs">
              <p className="font-medium text-ink">سلّم الإلغاء المطبَّق على هذا الحجز</p>
              {record.cancellation_rules.length === 0 ? (
                <p className="mt-1 text-muted">لا يوجد سلّم — الإلغاء بلا استرداد.</p>
              ) : (
                <ul className="mt-1.5 flex flex-col gap-1 text-ink-2">
                  {record.cancellation_rules.map((rule) => (
                    <li key={rule.hours_before}>• {describeRule(rule)}</li>
                  ))}
                </ul>
              )}
              {record.refunded_amount > 0 ? (
                <p className="mt-2 text-ink">
                  المسترجع فعلياً: {formatMoney(record.refunded_amount)}
                </p>
              ) : record.status === 'pending_provider' || record.status === 'confirmed' ? (
                <p className="mt-2 text-muted">
                  لو أُلغي الآن لاسترجع العميل {formatMoney(refundable)} من أصل{' '}
                  {formatMoney(record.paid_amount)}.
                </p>
              ) : null}
            </div>
          </CardBody>
        </Card>

        <Card className={cn('overflow-hidden', payments.refetching && 'is-refetching')}>
          <CardHeader
            title="مدفوعات الحجز"
            subtitle={`المحصّل: ${formatMoney(collected)}`}
            actions={
              <Link
                to="/payments"
                className="text-xs font-medium text-accent underline underline-offset-4"
              >
                السجل الكامل
              </Link>
            }
          />
          {payments.loading ? (
            <LoadingBlock />
          ) : payments.error && !payments.data ? (
            <ErrorState message={payments.error} onRetry={payments.reload} />
          ) : rows.length === 0 ? (
            <EmptyState title="لا توجد مدفوعات" />
          ) : (
            <ul className="divide-y divide-[var(--border)]">
              {rows.map((payment) => (
                <li key={payment.id} className="flex flex-col gap-1 px-4 py-3 sm:px-5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-sm font-medium text-ink">
                      {PAYMENT_KIND_LABEL[payment.kind]}
                    </span>
                    <span className="tnum text-sm text-ink">{formatMoney(payment.amount)}</span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[11px] text-muted">
                      {PAYMENT_METHOD_LABEL[payment.method]}
                    </span>
                    <Badge tone={PAYMENT_TONE[payment.status]}>
                      {PAYMENT_STATUS_LABEL[payment.status]}
                    </Badge>
                  </div>
                  <span className="tnum text-[11px] text-muted">
                    {formatDateTime(payment.created_at)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <ConfirmDialog
        open={pending !== null}
        title={pending?.title ?? ''}
        message={
          pending?.status === 'cancelled'
            ? `${pending.message} المستحق للعميل الآن: ${formatMoney(refundable)}.`
            : (pending?.message ?? '')
        }
        confirmLabel={pending?.label ?? 'تأكيد'}
        tone={pending?.status === 'cancelled' ? 'danger' : 'primary'}
        busy={busy}
        onConfirm={() =>
          pending &&
          run(
            () => setBookingStatus(record, pending.status, reason.trim()),
            `تم نقل الحجز إلى «${BOOKING_STATUS_LABEL[pending.status]}».`,
          )
        }
        onCancel={() => {
          setPending(null)
          setReason('')
        }}
      >
        <Field label="السبب" hint="يظهر في تفاصيل الحجز وفي سجل العمليات.">
          {(fieldId) => (
            <Textarea
              id={fieldId}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="مثال: تواصل مقدّم الخدمة هاتفياً وأكّد الموعد."
            />
          )}
        </Field>
      </ConfirmDialog>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

/** Progress trail; the end states that leave the path are shown on their own. */
function BookingTrail({ status }: { status: BookingStatus }) {
  const OFF_PATH: Partial<Record<BookingStatus, string>> = {
    cancelled: 'أُلغي هذا الحجز ولم يكمل مساره.',
    rejected: 'اعتذر مقدّم الخدمة عن هذا الحجز.',
    expired: 'انتهت مهلة الرد فأُغلق الحجز تلقائياً.',
  }

  const offPath = OFF_PATH[status]
  if (offPath) {
    return (
      <p className="flex items-center gap-2 rounded-lg border border-hairline px-3 py-2 text-xs text-ink-2">
        <XCircle size={14} aria-hidden style={{ color: 'var(--critical)' }} />
        {offPath}
      </p>
    )
  }

  const currentIndex = BOOKING_TRAIL.indexOf(status)

  return (
    <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-2">
      {BOOKING_TRAIL.map((stage, index) => {
        const done = index <= currentIndex
        return (
          <li key={stage} className="flex items-center gap-1.5">
            <span
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs whitespace-nowrap',
                done ? 'border-transparent bg-accent text-accent-ink' : 'border-hairline text-muted',
              )}
            >
              {/* The tick is what marks a completed stage, not the fill alone. */}
              {done ? <Check size={12} aria-hidden /> : null}
              {BOOKING_STATUS_LABEL[stage]}
            </span>
            {index < BOOKING_TRAIL.length - 1 ? (
              <span aria-hidden className="text-muted">
                ←
              </span>
            ) : null}
          </li>
        )
      })}
    </ol>
  )
}

function Note({ text, at }: { text: string; at: string | null }) {
  return (
    <p className="rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink">
      {text}
      {at ? ` · ${formatDate(at)}` : ''}
    </p>
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
