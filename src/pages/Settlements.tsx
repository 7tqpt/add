import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { BadgeCheck, Banknote, PauseCircle, Search } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney, formatNumber } from '@/lib/format'
import type { Settlement, SettlementStatus } from '@/lib/types'
import { SETTLEMENT_STATUS_LABEL, listSettlements, setSettlementStatus } from '@/services/finance'

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<SettlementStatus, Tone> = {
  pending: 'warning',
  approved: 'good',
  paid: 'good',
  on_hold: 'critical',
}

/** The next step available from each state, and how it reads to the admin. */
const NEXT: Partial<Record<SettlementStatus, { status: SettlementStatus; label: string }>> = {
  pending: { status: 'approved', label: 'اعتماد' },
  approved: { status: 'paid', label: 'تأكيد الصرف' },
}

export function SettlementsPage() {
  const { canWrite } = useAuth()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<SettlementStatus | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [pending, setPending] = useState<{ row: Settlement; next: SettlementStatus } | null>(null)
  const [busy, setBusy] = useState(false)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status])

  const load = useCallback(
    () => listSettlements({ search: debouncedSearch, status, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  // Totals for the page on screen, labelled as such so they are not mistaken
  // for the whole ledger.
  const rows = data?.rows ?? []
  const pageNet = rows.reduce((total, row) => total + row.net_amount, 0)

  async function run() {
    if (!pending) return
    setBusy(true)
    try {
      await setSettlementStatus(pending.row, pending.next)
      setToast(`نُقلت التسوية إلى «${SETTLEMENT_STATUS_LABEL[pending.next]}».`)
      reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusy(false)
      setPending(null)
    }
  }

  const buildExport = useCallback(async () => {
    const all = await listSettlements({
      search: debouncedSearch,
      status,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'رقم التسوية',
        'مقدّم الخدمة',
        'من',
        'إلى',
        'عدد الحجوزات',
        'الإجمالي',
        'العمولة',
        'الصافي',
        'طريقة الصرف',
        'الحالة',
        'تاريخ الصرف',
      ],
      rows: all.rows.map((row) => [
        row.reference,
        row.provider_name,
        formatDate(row.period_start),
        formatDate(row.period_end),
        row.bookings_count,
        row.gross_amount,
        row.commission_amount,
        row.net_amount,
        row.method,
        SETTLEMENT_STATUS_LABEL[row.status],
        row.paid_at ? formatDate(row.paid_at) : '',
      ]),
    }
  }, [debouncedSearch, status])

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
            placeholder="ابحث برقم التسوية أو اسم الشريك…"
            aria-label="بحث في التسويات"
            className="ps-9"
          />
        </div>

        <div className="w-44">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as SettlementStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(SETTLEMENT_STATUS_LABEL) as SettlementStatus[]).map((key) => (
              <option key={key} value={key}>
                {SETTLEMENT_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-مستحقات-الشركاء"
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
        ) : rows.length === 0 ? (
          <EmptyState
            title="لا توجد تسويات"
            description="جرّب تعديل البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {[
                    'التسوية',
                    'الفترة',
                    'الحجوزات',
                    'الإجمالي',
                    'العمولة المخصومة',
                    'الصافي',
                    'الحالة',
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
                {rows.map((row) => {
                  const next = NEXT[row.status]
                  return (
                    <tr
                      key={row.id}
                      className="border-b border-hairline last:border-0 hover:bg-surface-2"
                    >
                      <td className="px-4 py-3">
                        <Link
                          to={`/providers/${row.provider_id}`}
                          className="text-xs font-medium text-ink underline-offset-4 hover:text-series-1 hover:underline"
                        >
                          {row.provider_name}
                        </Link>
                        {/* The reference is Latin and the method is Arabic, so
                            they need separate direction contexts to stay legible. */}
                        <p className="text-[11px] whitespace-nowrap text-muted">
                          <span dir="ltr" className="tnum">
                            {row.reference}
                          </span>
                          {' · '}
                          {row.method}
                        </p>
                      </td>
                      <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatDate(row.period_start)} — {formatDate(row.period_end)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(row.bookings_count)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(row.gross_amount)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(row.commission_amount)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs font-medium whitespace-nowrap text-ink">
                        {formatMoney(row.net_amount)}
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone={STATUS_TONE[row.status]}>
                          {SETTLEMENT_STATUS_LABEL[row.status]}
                        </Badge>
                        {row.paid_at ? (
                          <span className="mt-0.5 block text-[11px] text-muted">
                            {formatDate(row.paid_at)}
                          </span>
                        ) : null}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-end gap-1.5">
                          {next ? (
                            <Button
                              size="sm"
                              variant={next.status === 'paid' ? 'primary' : 'secondary'}
                              disabled={busy || !canWrite}
                              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                              onClick={() => setPending({ row, next: next.status })}
                            >
                              {next.status === 'paid' ? (
                                <Banknote size={14} aria-hidden />
                              ) : (
                                <BadgeCheck size={14} aria-hidden />
                              )}
                              {next.label}
                            </Button>
                          ) : null}
                          {row.status === 'pending' || row.status === 'approved' ? (
                            <Button
                              size="sm"
                              variant="ghost"
                              disabled={busy || !canWrite}
                              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                              onClick={() => setPending({ row, next: 'on_hold' })}
                            >
                              <PauseCircle size={14} aria-hidden />
                              إيقاف
                            </Button>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {rows.length > 0 ? (
          <>
            <p className="tnum border-t border-hairline px-4 py-2.5 text-xs text-muted">
              صافي هذه الصفحة: {formatMoney(pageNet)}
            </p>
            <Pagination page={page} pageSize={PAGE_SIZE} total={data?.total ?? 0} onChange={setPage} />
          </>
        ) : null}
      </Card>

      <ConfirmDialog
        open={pending !== null}
        title={
          pending?.next === 'paid'
            ? 'تأكيد صرف المستحقات؟'
            : pending?.next === 'on_hold'
              ? 'إيقاف التسوية؟'
              : 'اعتماد التسوية؟'
        }
        message={
          pending
            ? pending.next === 'paid'
              ? `سجّل صرف ${formatMoney(pending.row.net_amount)} إلى ${pending.row.provider_name} عبر ${pending.row.method}. سجّلها بعد إتمام التحويل فعلياً.`
              : pending.next === 'on_hold'
                ? 'تبقى التسوية موقوفة حتى تُراجَع يدوياً، ولن تظهر ضمن الدفعات المستحقة.'
                : `تُعتمد التسوية للصرف بمبلغ صافٍ ${formatMoney(pending.row.net_amount)}.`
            : ''
        }
        confirmLabel="تأكيد"
        tone={pending?.next === 'on_hold' ? 'danger' : 'primary'}
        busy={busy}
        onConfirm={run}
        onCancel={() => setPending(null)}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
