import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, Ban, Check, ChevronLeft, MapPin, XCircle } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Textarea } from '@/components/ui/Field'
import { Rating } from '@/components/ui/Rating'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatDateTime, formatDuration, formatMoney } from '@/lib/format'
import type { OrderOffer, OrderStatus, PaymentStatus } from '@/lib/types'
import {
  OFFER_STATUS_LABEL,
  ORDER_STATUS_LABEL,
  ORDER_TRAIL,
  acceptOffer,
  advanceOrder,
  cancelOrder,
  getOrder,
  getOrderDetail,
  nextStatusOf,
} from '@/services/orders'
import { PAYMENT_KIND_LABEL, PAYMENT_STATUS_LABEL } from '@/services/payments'

const STATUS_TONE: Record<OrderStatus, Tone> = {
  new: 'warning',
  confirmed: 'good',
  on_the_way: 'good',
  in_progress: 'good',
  completed: 'good',
  closed: 'neutral',
  cancelled: 'critical',
}

const PAYMENT_TONE: Record<PaymentStatus, Tone> = {
  paid: 'good',
  pending: 'warning',
  failed: 'critical',
  refunded: 'serious',
}

export function OrderDetailPage() {
  const { id = '' } = useParams()
  const { canWrite } = useAuth()
  const [toast, setToast] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [pendingOffer, setPendingOffer] = useState<OrderOffer | null>(null)
  const [cancelling, setCancelling] = useState(false)
  const [reason, setReason] = useState('')

  const loadOrder = useCallback(() => getOrder(id), [id])
  const loadDetail = useCallback(() => getOrderDetail(id), [id])

  const order = useAsync(loadOrder, [id])
  const detail = useAsync(loadDetail, [id])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2800)
    return () => clearTimeout(timer)
  }, [toast])

  function reloadAll() {
    order.reload()
    detail.reload()
  }

  async function run(action: () => Promise<void>, message: string) {
    setBusy(true)
    try {
      await action()
      setToast(message)
      reloadAll()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusy(false)
      setPendingOffer(null)
      setCancelling(false)
    }
  }

  if (order.loading) return <LoadingBlock />
  if (order.error && !order.data) return <ErrorState message={order.error} onRetry={order.reload} />
  if (!order.data) {
    return (
      <Card>
        <EmptyState
          title="الطلب غير موجود"
          description="ربما حُذف الطلب أو أن الرابط غير صحيح."
          action={
            <Link to="/orders" className="text-sm font-medium text-series-1 underline underline-offset-4">
              العودة إلى الطلبات
            </Link>
          }
        />
      </Card>
    )
  }

  const record = order.data
  const offers = detail.data?.offers ?? []
  const payments = detail.data?.payments ?? []
  const next = nextStatusOf(record.status)
  const canCancel = record.status !== 'cancelled' && record.status !== 'closed'
  const paidTotal = payments
    .filter((payment) => payment.status === 'paid')
    .reduce((sum, payment) => sum + payment.amount, 0)

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/orders"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        {/* Under RTL "back" points toward the start edge, which is the right. */}
        <ArrowRight size={14} aria-hidden />
        كل الطلبات
      </Link>

      <Card>
        <CardHeader
          title={
            <span dir="ltr" className="tnum block text-start">
              {record.reference}
            </span>
          }
          subtitle={`${record.category} · ${record.city}`}
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Badge
                tone={STATUS_TONE[record.status]}
                icon={record.status === 'cancelled' ? XCircle : true}
              >
                {ORDER_STATUS_LABEL[record.status]}
              </Badge>

              {next ? (
                <Button
                  size="sm"
                  variant="primary"
                  disabled={busy || !canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() =>
                    run(
                      () => advanceOrder(record, next),
                      `تم نقل الطلب إلى «${ORDER_STATUS_LABEL[next]}».`,
                    )
                  }
                >
                  {ORDER_STATUS_LABEL[next]}
                  <ChevronLeft size={14} aria-hidden />
                </Button>
              ) : null}

              {canCancel ? (
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={busy || !canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() => setCancelling(true)}
                >
                  <Ban size={14} aria-hidden />
                  إلغاء
                </Button>
              ) : null}
            </div>
          }
        />
        <CardBody className="flex flex-col gap-4">
          <OrderTrail status={record.status} />

          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-5">
            <Detail
              label="العميل"
              node={
                <Link
                  to={`/users/${record.user_id}`}
                  className="underline-offset-4 hover:text-series-1 hover:underline"
                >
                  {record.user_name}
                </Link>
              }
            />
            <Detail
              label="مقدّم الخدمة"
              node={
                record.provider_id ? (
                  <Link
                    to={`/providers/${record.provider_id}`}
                    className="underline-offset-4 hover:text-series-1 hover:underline"
                  >
                    {record.provider_name}
                  </Link>
                ) : (
                  <span className="text-muted">لم يُقبل عرض بعد</span>
                )
              }
            />
            <Detail label="الموعد المجدول" value={formatDateTime(record.scheduled_at)} />
            <Detail label="رسم الحجز" value={formatMoney(record.booking_fee)} />
            <Detail
              label="السعر النهائي"
              value={record.final_price ? formatMoney(record.final_price) : '—'}
            />
          </dl>

          <div className="flex items-start gap-2 rounded-lg border border-hairline bg-surface-2 px-3 py-2.5">
            <MapPin size={14} aria-hidden className="mt-0.5 shrink-0 text-muted" />
            <div className="min-w-0 text-xs">
              <p className="text-ink">{record.address}</p>
              <p className="mt-1 leading-6 text-ink-2">{record.description}</p>
            </div>
          </div>

          {record.status === 'cancelled' && record.cancel_reason ? (
            <p className="rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink">
              سبب الإلغاء: {record.cancel_reason}
              {record.cancelled_at ? ` · ${formatDate(record.cancelled_at)}` : ''}
            </p>
          ) : null}
        </CardBody>
      </Card>

      {detail.loading ? (
        <Card>
          <LoadingBlock />
        </Card>
      ) : detail.error && !detail.data ? (
        <Card>
          <ErrorState message={detail.error} onRetry={detail.reload} />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
          <div className="xl:col-span-2">
            <Card className={cn('overflow-hidden', detail.refetching && 'is-refetching')}>
              <CardHeader
                title="عروض الأسعار"
                subtitle={
                  record.status === 'new'
                    ? `${offers.length} عرض — بانتظار اختيار العميل`
                    : 'العرض المقبول ومَن نافسه'
                }
              />
              {offers.length === 0 ? (
                <EmptyState
                  title="لا توجد عروض بعد"
                  description="لم يقدّم أي مقدّم خدمة عرضاً على هذا الطلب."
                />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full border-collapse text-xs">
                    <thead>
                      <tr className="bg-surface-2">
                        {['مقدّم الخدمة', 'التقييم', 'السعر', 'المدة', 'ملاحظة', 'الحالة', ''].map(
                          (heading, index) => (
                            <th
                              key={index}
                              scope="col"
                              className="border-b border-hairline px-4 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                            >
                              {heading}
                            </th>
                          ),
                        )}
                      </tr>
                    </thead>
                    <tbody>
                      {offers.map((offer) => (
                        <tr
                          key={offer.id}
                          className={cn(
                            'border-b border-hairline last:border-0',
                            offer.status === 'accepted' && 'bg-surface-2',
                          )}
                        >
                          <td className="px-4 py-2.5 whitespace-nowrap text-ink">
                            <Link
                              to={`/providers/${offer.provider_id}`}
                              className="underline-offset-4 hover:text-series-1 hover:underline"
                            >
                              {offer.provider_name}
                            </Link>
                          </td>
                          <td className="px-4 py-2.5">
                            <Rating value={offer.provider_rating} />
                          </td>
                          <td className="tnum px-4 py-2.5 font-medium whitespace-nowrap text-ink">
                            {formatMoney(offer.price)}
                          </td>
                          <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                            {formatDuration(offer.duration_minutes * 60)}
                          </td>
                          {/* Every other column is nowrap, so without a floor the
                              note gets squeezed to one word per line. */}
                          <td className="min-w-44 px-4 py-2.5 text-ink-2">{offer.note || '—'}</td>
                          <td className="px-4 py-2.5">
                            <Badge
                              tone={
                                offer.status === 'accepted'
                                  ? 'good'
                                  : offer.status === 'pending'
                                    ? 'warning'
                                    : 'neutral'
                              }
                              icon={offer.status === 'rejected' ? XCircle : true}
                            >
                              {OFFER_STATUS_LABEL[offer.status]}
                            </Badge>
                          </td>
                          <td className="px-4 py-2.5 text-end">
                            {/* Accepting is only possible while the order is still
                                open — afterwards the price and provider are fixed. */}
                            {record.status === 'new' && offer.status === 'pending' ? (
                              <Button
                                size="sm"
                                disabled={busy || !canWrite}
                                title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                                onClick={() => setPendingOffer(offer)}
                              >
                                <Check size={14} aria-hidden />
                                قبول
                              </Button>
                            ) : null}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          </div>

          <Card className="overflow-hidden">
            <CardHeader
              title="مدفوعات الطلب"
              subtitle={`المحصّل: ${formatMoney(paidTotal)}`}
              actions={
                <Link
                  to="/payments"
                  className="text-xs font-medium text-series-1 underline underline-offset-4"
                >
                  السجل الكامل
                </Link>
              }
            />
            {payments.length === 0 ? (
              <EmptyState title="لا توجد مدفوعات" />
            ) : (
              <ul className="divide-y divide-[var(--border)]">
                {payments.map((payment) => (
                  <li key={payment.id} className="flex flex-col gap-1 px-4 py-3 sm:px-5">
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-sm font-medium text-ink">
                        {PAYMENT_KIND_LABEL[payment.kind]}
                      </span>
                      <span className="tnum text-sm text-ink">{formatMoney(payment.amount)}</span>
                    </div>
                    <div className="flex items-center justify-between gap-2">
                      <span dir="ltr" className="tnum text-start text-[11px] text-muted">
                        {payment.reference}
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
      )}

      <ConfirmDialog
        open={pendingOffer !== null}
        title="قبول هذا العرض؟"
        message={
          pendingOffer
            ? `سيُسنَد الطلب إلى ${pendingOffer.provider_name} بسعر ${formatMoney(pendingOffer.price)}، وتُرفض بقية العروض، ويُقيَّد رصيد الطلب على العميل. لا يمكن التراجع.`
            : ''
        }
        confirmLabel="قبول وتأكيد الطلب"
        tone="primary"
        busy={busy}
        onConfirm={() =>
          pendingOffer && run(() => acceptOffer(record, pendingOffer), 'تم قبول العرض وتأكيد الطلب.')
        }
        onCancel={() => setPendingOffer(null)}
      />

      <ConfirmDialog
        open={cancelling}
        title="إلغاء الطلب؟"
        message={`سيُلغى الطلب ${record.reference}. المبالغ المدفوعة لا تُسترجع تلقائياً — نفّذ الاسترجاع من شاشة عمليات الدفع إن كان مستحقاً.`}
        confirmLabel="تأكيد الإلغاء"
        busy={busy}
        onConfirm={() =>
          run(
            () => cancelOrder(record, reason.trim() || 'أُلغي من لوحة التحكم.'),
            'تم إلغاء الطلب.',
          )
        }
        onCancel={() => setCancelling(false)}
      >
        <Field label="سبب الإلغاء" hint="يظهر في تفاصيل الطلب وسجل العمليات.">
          {(fieldId) => (
            <Textarea
              id={fieldId}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="مثال: العميل طلب الإلغاء لتعذّر الموعد."
            />
          )}
        </Field>
      </ConfirmDialog>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

/** Progress trail; the cancelled case is shown as its own end state instead. */
function OrderTrail({ status }: { status: OrderStatus }) {
  if (status === 'cancelled') {
    return (
      <p className="flex items-center gap-2 rounded-lg border border-hairline px-3 py-2 text-xs text-ink-2">
        <XCircle size={14} aria-hidden style={{ color: 'var(--critical)' }} />
        أُلغي هذا الطلب ولم يكمل مساره.
      </p>
    )
  }

  const currentIndex = ORDER_TRAIL.indexOf(status)

  return (
    <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-2">
      {ORDER_TRAIL.map((stage, index) => {
        const done = index <= currentIndex
        return (
          <li key={stage} className="flex items-center gap-1.5">
            <span
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs whitespace-nowrap',
                done
                  ? 'border-transparent bg-series-1 text-white'
                  : 'border-hairline text-muted',
              )}
            >
              {/* The tick is what marks a completed stage, not the fill alone. */}
              {done ? <Check size={12} aria-hidden /> : null}
              {ORDER_STATUS_LABEL[stage]}
            </span>
            {index < ORDER_TRAIL.length - 1 ? (
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

function Detail({ label, value, node }: { label: string; value?: string; node?: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-muted">{label}</dt>
      <dd className="mt-0.5 truncate font-medium text-ink">{node ?? value}</dd>
    </div>
  )
}
