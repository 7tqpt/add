import { useEffect, useState } from 'react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney } from '@/lib/format'
import { errorText } from '@/services/base'
import {
  decideRefund,
  decideWithdrawal,
  listPendingRefunds,
  listWithdrawals,
  WITHDRAWAL_METHOD_LABEL,
  WITHDRAWAL_STATUS_LABEL,
  type PendingRefund,
  type Withdrawal,
  type WithdrawalStatus,
} from '@/services/wallet'

const TH = 'border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2'
const TD = 'px-4 py-3 text-xs whitespace-nowrap text-ink-2'

/**
 * «طلبات السحب» — صورةُ صاحب المنصّة التي وافق عليها، ومعها ما اختاره بعدها.
 *
 * فوقُ: **استرجاعاتٌ بانتظار الاعتماد** — الإلغاءُ يحسبها بسلّم الإلغاء، ولا
 * تدخل رصيدَ العميل حتى تُعتمد هنا (اختيارُه (ب)). وتحتُ: **طلباتُ السحب**،
 * بجانب كلٍّ الرقمُ الذي كتبه العميل والرقمُ في سجلّ دفعه — «عشن غسل الامول».
 */
export function WithdrawalsPage() {
  const { can } = useAuth()
  const canWrite = can('finance')
  const [status, setStatus] = useState<WithdrawalStatus | 'all'>('pending')
  const [toast, setToast] = useState<string | null>(null)

  const refunds = useAsync(listPendingRefunds, [])
  const withdrawals = useAsync(() => listWithdrawals(status), [status])

  const [refundAction, setRefundAction] = useState<{ refund: PendingRefund; approve: boolean } | null>(null)
  const [refundAmount, setRefundAmount] = useState('')
  const [withdrawalAction, setWithdrawalAction] = useState<{ withdrawal: Withdrawal; paid: boolean } | null>(null)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [dialogError, setDialogError] = useState<string | null>(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  function openRefund(refund: PendingRefund, approve: boolean) {
    setRefundAction({ refund, approve })
    setRefundAmount(String(refund.amount))
    setNote('')
    setDialogError(null)
  }

  function openWithdrawal(withdrawal: Withdrawal, paid: boolean) {
    setWithdrawalAction({ withdrawal, paid })
    setNote('')
    setDialogError(null)
  }

  async function confirmRefund() {
    if (!refundAction) return
    setBusy(true)
    setDialogError(null)
    try {
      const amount = refundAction.approve ? Number(refundAmount.replace(/[^\d.]/g, '')) : null
      await decideRefund(refundAction.refund, refundAction.approve, amount, note)
      setToast(
        refundAction.approve
          ? `دخل ${formatMoney(amount ?? refundAction.refund.amount)} رصيدَ ${refundAction.refund.user_name}.`
          : `لم يُعتمد استرجاعُ ${refundAction.refund.booking_reference}.`,
      )
      setRefundAction(null)
      refunds.reload()
    } catch (cause) {
      setDialogError(errorText(cause, 'تعذّر تنفيذ الإجراء.'))
    } finally {
      setBusy(false)
    }
  }

  async function confirmWithdrawal() {
    if (!withdrawalAction) return
    setBusy(true)
    setDialogError(null)
    try {
      await decideWithdrawal(withdrawalAction.withdrawal, withdrawalAction.paid, note)
      setToast(
        withdrawalAction.paid
          ? `سُجّل تحويلُ ${withdrawalAction.withdrawal.reference} ووصل العميلَ إشعار.`
          : `رُفض ${withdrawalAction.withdrawal.reference} وعاد المبلغ إلى رصيده.`,
      )
      setWithdrawalAction(null)
      withdrawals.reload()
    } catch (cause) {
      setDialogError(errorText(cause, 'تعذّر تنفيذ الإجراء.'))
    } finally {
      setBusy(false)
    }
  }

  const readOnly = canWrite ? undefined : 'دورك الحالي للقراءة فقط'

  return (
    <div className="flex flex-col gap-5">
      <Card className={cn('overflow-hidden', refunds.refetching && 'is-refetching')}>
        <CardHeader
          title="استرجاعاتٌ بانتظار الاعتماد"
          subtitle="حسبها سلّمُ الإلغاء أو رفضُ مقدّم الخدمة — ولا تدخل رصيدَ العميل حتى تعتمدها"
        />
        {refunds.loading ? (
          <LoadingBlock />
        ) : refunds.error && !refunds.data ? (
          <ErrorState message={refunds.error} onRetry={refunds.reload} />
        ) : !refunds.data || refunds.data.length === 0 ? (
          <EmptyState title="لا استرجاعات تنتظر" description="كلُّ استرجاعٍ محسوبٍ قُرّر." />
        ) : (
          <div className="overflow-x-auto">
            <table data-refunds className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {['الحجز', 'العميل', 'مقدّم الخدمة', 'المحسوب', 'الإجراء'].map((h) => (
                    <th key={h} scope="col" className={TH}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {refunds.data.map((refund) => (
                  <tr key={refund.id} className="glass-row border-b border-hairline last:border-0">
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span dir="ltr" className="tnum font-medium text-ink">{refund.booking_reference}</span>
                      <span className="block text-[11px] text-muted">
                        {refund.booking_status === 'rejected' ? 'اعتذر مقدّم الخدمة' : 'ألغى العميل'} ·{' '}
                        {formatDate(refund.created_at)}
                      </span>
                    </td>
                    <td className={TD}>{refund.user_name}</td>
                    <td className={TD}>{refund.provider_name}</td>
                    <td className={cn(TD, 'tnum font-semibold text-ink')}>{formatMoney(refund.amount)}</td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <Button size="sm" variant="primary" disabled={!canWrite} title={readOnly}
                          onClick={() => openRefund(refund, true)}>
                          اعتماد إلى رصيده
                        </Button>
                        <Button size="sm" variant="secondary" disabled={!canWrite} title={readOnly}
                          onClick={() => openRefund(refund, false)}>
                          رفض
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card className={cn('overflow-hidden', withdrawals.refetching && 'is-refetching')}>
        <CardHeader
          title="طلباتُ سحب «رصيد فرحتي»"
          subtitle="قارِن الرقمَ الذي أدخله العميل بما في سجلّ دفعه، ثمّ حوِّل إليه واضغط «حوّلتُ المبلغ»"
          actions={
            <Select
              aria-label="حال الطلب"
              className="w-40"
              value={status}
              onChange={(event) => setStatus(event.target.value as WithdrawalStatus | 'all')}
            >
              <option value="pending">بانتظار التحويل</option>
              <option value="paid">حُوِّل</option>
              <option value="rejected">مرفوض</option>
              <option value="all">الكلّ</option>
            </Select>
          }
        />
        {withdrawals.loading ? (
          <LoadingBlock />
        ) : withdrawals.error && !withdrawals.data ? (
          <ErrorState message={withdrawals.error} onRetry={withdrawals.reload} />
        ) : !withdrawals.data || withdrawals.data.length === 0 ? (
          <EmptyState title="لا طلبات هنا" description="لا طلبَ سحبٍ بهذه الحال." />
        ) : (
          <div className="overflow-x-auto">
            <table data-withdrawals className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {['الطلب', 'العميل', 'المبلغ', 'دفع منه — أدخله العميل', 'في سجلّ الدفع', 'الإجراء'].map((h) => (
                    <th key={h} scope="col" className={TH}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {withdrawals.data.map((w) => (
                  <tr key={w.id} data-withdrawal={w.reference} className="glass-row border-b border-hairline last:border-0">
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span dir="ltr" className="tnum font-medium text-ink">{w.reference}</span>
                      <span className="block text-[11px] text-muted">{formatDate(w.created_at)}</span>
                    </td>
                    <td className={TD}>
                      {w.user_name ?? '—'}
                      {w.paid_booking ? (
                        <span dir="ltr" className="block text-[11px] text-muted">{w.paid_booking}</span>
                      ) : null}
                    </td>
                    <td className={cn(TD, 'tnum font-semibold text-ink')}>{formatMoney(w.amount)}</td>
                    <td className={TD}>
                      {WITHDRAWAL_METHOD_LABEL[w.method]}{' '}
                      <span dir="ltr" data-entered className="tnum font-semibold text-ink">{w.account}</span>
                    </td>
                    <td className={TD}>
                      <span dir="ltr" data-paid-account className="tnum">{w.paid_account ?? '—'}</span>{' '}
                      <span data-match={w.matched ? 'yes' : 'no'}>
                        <Badge tone={w.matched ? 'good' : 'critical'}>{w.matched ? 'مطابق' : 'غير مطابق'}</Badge>
                      </span>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      {w.status === 'pending' ? (
                        <div className="flex items-center gap-2">
                          <Button size="sm" variant="primary" disabled={!canWrite} title={readOnly}
                            onClick={() => openWithdrawal(w, true)}>
                            حوّلتُ المبلغ
                          </Button>
                          <Button size="sm" variant="secondary" disabled={!canWrite} title={readOnly}
                            onClick={() => openWithdrawal(w, false)}>
                            رفض
                          </Button>
                        </div>
                      ) : (
                        <span title={w.note || undefined}>
                          <Badge tone={w.status === 'paid' ? 'good' : 'neutral'}>
                            {WITHDRAWAL_STATUS_LABEL[w.status]}
                          </Badge>
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <ConfirmDialog
        open={refundAction !== null}
        tone={refundAction?.approve ? 'primary' : 'danger'}
        title={refundAction?.approve ? 'اعتمادُ الاسترجاع إلى رصيد العميل' : 'رفضُ الاسترجاع'}
        message={
          refundAction?.approve
            ? `يدخل المبلغُ «رصيد فرحتي» عند ${refundAction.refund.user_name} فوراً، فيدفع منه أو يطلب سحبَه. ولك أن تُنقص المبلغ لا أن تزيده.`
            : 'لا يدخل رصيدَ العميل شيء، ويعود المبلغُ مستحقّاً لمقدّم الخدمة في الحجز. والسببُ يصل العميل.'
        }
        confirmLabel={refundAction?.approve ? 'اعتماد' : 'رفض الاسترجاع'}
        busy={busy}
        error={dialogError}
        confirmDisabled={refundAction !== null && !refundAction.approve && !note.trim()}
        onConfirm={() => void confirmRefund()}
        onCancel={() => setRefundAction(null)}
      >
        {refundAction?.approve ? (
          <Field label="المبلغ (ر.ي)" hint={`المحسوب: ${formatMoney(refundAction.refund.amount)}`}>
            {(id) => (
              <Input id={id} dir="ltr" inputMode="numeric" value={refundAmount}
                onChange={(event) => setRefundAmount(event.target.value)} />
            )}
          </Field>
        ) : null}
        <Field label={refundAction?.approve ? 'ملاحظة (اختياريّة)' : 'سبب الرفض'}>
          {(id) => <Input id={id} value={note} onChange={(event) => setNote(event.target.value)} />}
        </Field>
      </ConfirmDialog>

      <ConfirmDialog
        open={withdrawalAction !== null}
        tone={withdrawalAction?.paid ? 'primary' : 'danger'}
        title={withdrawalAction?.paid ? 'هل حوّلتَ المبلغ؟' : 'رفضُ طلب السحب'}
        message={
          withdrawalAction?.paid
            ? `اضغط «حوّلتُ» بعد أن ترسل ${formatMoney(withdrawalAction.withdrawal.amount)} إلى ${WITHDRAWAL_METHOD_LABEL[withdrawalAction.withdrawal.method]} ${withdrawalAction.withdrawal.account} — فيصل العميلَ إشعارٌ بالتحويل.`
            : 'يعود المبلغ إلى رصيد العميل، ويصله السبب.'
        }
        confirmLabel={withdrawalAction?.paid ? 'حوّلتُ' : 'رفض الطلب'}
        busy={busy}
        error={dialogError}
        confirmDisabled={withdrawalAction !== null && !withdrawalAction.paid && !note.trim()}
        onConfirm={() => void confirmWithdrawal()}
        onCancel={() => setWithdrawalAction(null)}
      >
        <Field label={withdrawalAction?.paid ? 'رقم عملية التحويل (اختياريّ)' : 'سبب الرفض'}>
          {(id) => <Input id={id} value={note} onChange={(event) => setNote(event.target.value)} />}
        </Field>
      </ConfirmDialog>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
