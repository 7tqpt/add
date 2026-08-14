import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Banknote, PercentCircle, RotateCcw, Search, TrendingUp, Undo2 } from 'lucide-react'
import { BarChart } from '@/components/charts/BarChart'
import { StatTile } from '@/components/charts/StatTile'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import {
  formatDate,
  formatDateTime,
  formatMoney,
  formatMoneyCompact,
  formatNumber,
  formatPercent,
} from '@/lib/format'
import type { Payment, PaymentKind, PaymentMethod, PaymentStatus } from '@/lib/types'
import {
  PAYMENT_KIND_LABEL,
  PAYMENT_METHOD_LABEL,
  PAYMENT_STATUS_LABEL,
  getPaymentTotals,
  listPayments,
  refundPayment,
} from '@/services/finance'

const PAGE_SIZE = 12
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<PaymentStatus, Tone> = {
  paid: 'good',
  pending: 'warning',
  failed: 'critical',
  refunded: 'serious',
}

const RANGES: { value: number | 'all'; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
  { value: 'all', label: 'كل الفترات' },
]

export function PaymentsPage() {
  const { can } = useAuth()
  const canWrite = can('finance')
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<PaymentStatus | 'all'>('all')
  const [method, setMethod] = useState<PaymentMethod | 'all'>('all')
  const [kind, setKind] = useState<PaymentKind | 'all'>('all')
  const [days, setDays] = useState<number | 'all'>(30)
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [pending, setPending] = useState<Payment | null>(null)
  const [busy, setBusy] = useState(false)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, method, kind, days])

  const filters = useMemo(
    () => ({ search: debouncedSearch, status, method, kind, days }),
    [debouncedSearch, status, method, kind, days],
  )

  const loadRows = useCallback(
    () => listPayments({ ...filters, page, pageSize: PAGE_SIZE }),
    [filters, page],
  )
  const loadTotals = useCallback(() => getPaymentTotals(filters), [filters])

  const rows = useAsync(loadRows, [filters, page])
  const totals = useAsync(loadTotals, [filters])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function applyRefund(payment: Payment) {
    setBusy(true)
    try {
      await refundPayment(payment)
      setToast(`تم استرجاع ${formatMoney(payment.amount)} للعميل.`)
      rows.reload()
      totals.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الاسترجاع.')
    } finally {
      setBusy(false)
      setPending(null)
    }
  }

  const buildExport = useCallback(async () => {
    const all = await listPayments({ ...filters, page: 0, pageSize: EXPORT_LIMIT })
    return {
      columns: [
        'المرجع',
        'التاريخ',
        'الحجز',
        'العميل',
        'مقدّم الخدمة',
        'النوع',
        'الوصف',
        'طريقة الدفع',
        'المبلغ',
        'حصة المنصة',
        'مستحق مقدّم الخدمة',
        'الحالة',
        'مرجع البوابة',
      ],
      rows: all.rows.map((payment) => [
        payment.reference,
        formatDate(payment.created_at),
        payment.booking_reference,
        payment.user_name,
        payment.provider_name,
        PAYMENT_KIND_LABEL[payment.kind],
        payment.description,
        PAYMENT_METHOD_LABEL[payment.method],
        payment.amount,
        payment.platform_share,
        payment.net_amount,
        PAYMENT_STATUS_LABEL[payment.status],
        payment.gateway_ref,
      ]),
    }
  }, [filters])

  return (
    <div className="flex flex-col gap-4">
      {/* One filter row above everything it scopes — the KPIs, the breakdown and
          the table all read from the same slice. */}
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
            aria-label="بحث في المدفوعات"
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

        <div className="w-32">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as PaymentStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(PAYMENT_STATUS_LABEL) as PaymentStatus[]).map((key) => (
              <option key={key} value={key}>
                {PAYMENT_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={method}
            onChange={(event) => setMethod(event.target.value as PaymentMethod | 'all')}
            aria-label="تصفية حسب طريقة الدفع"
          >
            <option value="all">كل طرق الدفع</option>
            {(Object.keys(PAYMENT_METHOD_LABEL) as PaymentMethod[]).map((key) => (
              <option key={key} value={key}>
                {PAYMENT_METHOD_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-32">
          <Select
            value={kind}
            onChange={(event) => setKind(event.target.value as PaymentKind | 'all')}
            aria-label="تصفية حسب النوع"
          >
            <option value="all">كل الأنواع</option>
            {(Object.keys(PAYMENT_KIND_LABEL) as PaymentKind[]).map((key) => (
              <option key={key} value={key}>
                {PAYMENT_KIND_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-المدفوعات"
          build={buildExport}
          disabled={!rows.data || rows.data.total === 0}
          onError={setToast}
        />
      </div>

      {totals.loading ? (
        <Card>
          <LoadingBlock />
        </Card>
      ) : totals.data ? (
        <>
          <div className="stagger grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatTile
              label="المبالغ المحصّلة"
              tone="emerald"
              value={formatMoneyCompact(totals.data.collected)}
              valueTitle={formatMoney(totals.data.collected)}
              icon={Banknote}
              refetching={totals.refetching}
            />
            <StatTile
              label="حصة المنصة"
              tone="navy"
              value={formatMoneyCompact(totals.data.platformShare)}
              valueTitle={formatMoney(totals.data.platformShare)}
              icon={PercentCircle}
              refetching={totals.refetching}
            />
            <StatTile
              label={`المسترجع (${formatNumber(totals.data.refundedCount)} عملية)`}
              tone="violet"
              value={formatMoneyCompact(totals.data.refunded)}
              valueTitle={formatMoney(totals.data.refunded)}
              icon={Undo2}
              refetching={totals.refetching}
            />
            <StatTile
              label="نسبة نجاح العمليات"
              tone="cyan"
              value={formatPercent(totals.data.successRate)}
              icon={TrendingUp}
              refetching={totals.refetching}
            />
          </div>

          {totals.data.byMethod.length > 0 ? (
            <Card className={cn(totals.refetching && 'is-refetching')}>
              <CardHeader
                title="التوزيع حسب طريقة الدفع"
                subtitle="المبالغ المحصّلة فقط — لا تشمل العمليات الفاشلة أو المسترجعة"
              />
              <CardBody>
                <BarChart
                  data={totals.data.byMethod.map((entry) => ({
                    label: PAYMENT_METHOD_LABEL[entry.method],
                    value: entry.amount,
                  }))}
                  formatValue={formatMoney}
                />
              </CardBody>
            </Card>
          ) : null}
        </>
      ) : null}

      <Card className={cn('overflow-hidden', rows.refetching && 'is-refetching')}>
        {rows.loading ? (
          <LoadingBlock />
        ) : rows.error && !rows.data ? (
          <ErrorState message={rows.error} onRetry={rows.reload} />
        ) : !rows.data || rows.data.rows.length === 0 ? (
          <EmptyState
            title="لا توجد عمليات"
            description="جرّب توسيع الفترة الزمنية أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {[
                    'المرجع',
                    'العميل',
                    'مقدّم الخدمة',
                    'النوع',
                    'الطريقة',
                    'المبلغ',
                    'حصة المنصة',
                    'الحالة',
                    'التاريخ',
                    '',
                  ].map((heading, index) => (
                    <th
                      key={index}
                      scope="col"
                      className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.data.rows.map((payment) => (
                  <tr
                    key={payment.id}
                    className="border-b border-hairline last:border-0 hover:bg-surface-2"
                  >
                    <td className="px-4 py-3">
                      <p
                        dir="ltr"
                        className="tnum text-start text-xs font-medium whitespace-nowrap text-ink"
                      >
                        {payment.reference}
                      </p>
                      <p className="text-xs text-muted">{payment.description}</p>
                      {payment.booking_id ? (
                        <Link
                          to={`/bookings/${payment.booking_id}`}
                          dir="ltr"
                          className="tnum block text-start text-[11px] text-muted underline-offset-4 hover:text-accent hover:underline"
                        >
                          {payment.booking_reference}
                        </Link>
                      ) : null}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      <Link
                        to={`/users/${payment.user_id}`}
                        className="underline-offset-4 hover:text-accent hover:underline"
                      >
                        {payment.user_name}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {payment.provider_id ? (
                        <Link
                          to={`/providers/${payment.provider_id}`}
                          className="underline-offset-4 hover:text-accent hover:underline"
                        >
                          {payment.provider_name}
                        </Link>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {PAYMENT_KIND_LABEL[payment.kind]}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {PAYMENT_METHOD_LABEL[payment.method]}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink">
                      {formatMoney(payment.amount)}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatMoney(payment.platform_share)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone={STATUS_TONE[payment.status]}>
                        {PAYMENT_STATUS_LABEL[payment.status]}
                      </Badge>
                    </td>
                    <td
                      className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2"
                      title={formatDateTime(payment.created_at)}
                    >
                      {formatDate(payment.created_at)}
                    </td>
                    <td className="px-4 py-3 text-end">
                      {/* Only a settled payment can be refunded — a failed or
                          already-refunded one has nothing to send back. */}
                      {payment.status === 'paid' ? (
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={busy || !canWrite}
                          title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                          onClick={() => setPending(payment)}
                        >
                          <RotateCcw size={14} aria-hidden />
                          استرجاع
                        </Button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {rows.data && rows.data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={rows.data.total} onChange={setPage} />
        ) : null}
      </Card>

      <ConfirmDialog
        open={pending !== null}
        title="استرجاع المبلغ للعميل؟"
        message={
          pending
            ? `سيُعاد ${formatMoney(pending.amount)} إلى ${pending.user_name} عبر ${PAYMENT_METHOD_LABEL[pending.method]}. الاسترجاع لا يمكن التراجع عنه، وسيُسجَّل باسمك في سجل العمليات.`
            : ''
        }
        confirmLabel="تنفيذ الاسترجاع"
        busy={busy}
        onConfirm={() => pending && applyRefund(pending)}
        onCancel={() => setPending(null)}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
