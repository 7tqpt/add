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
import { DAY_FORMS, formatCount, formatDate, formatMoney, formatNumber } from '@/lib/format'
import type { PlanStatus } from '@/lib/types'
import { GOVERNORATES } from '@/services/directory'
import { PLAN_STATUS_LABEL, daysUntil, listPlans } from '@/services/plans'

const PAGE_SIZE = 10
const EXPORT_LIMIT = 5000

export const PLAN_STATUS_TONE: Record<PlanStatus, Tone> = {
  planning: 'warning',
  confirmed: 'good',
  completed: 'neutral',
  cancelled: 'critical',
}

/** "بعد 12 يوماً" / "اليوم" / "مضى 4 أيام". */
function countdown(isoDate: string): string {
  const days = daysUntil(isoDate)
  if (days === 0) return 'اليوم'
  if (days === 1) return 'غداً'
  if (days > 0) return `بعد ${formatCount(days, DAY_FORMS)}`
  return `مضى ${formatCount(days, DAY_FORMS)}`
}

export function PlansPage() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<PlanStatus | 'all'>('all')
  const [governorate, setGovernorate] = useState<string | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, governorate])

  const load = useCallback(
    () => listPlans({ search: debouncedSearch, status, governorate, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, governorate, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    governorate,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listPlans({
      search: debouncedSearch,
      status,
      governorate,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: [
        'الخطة',
        'العميل',
        'تاريخ العرس',
        'المحافظة',
        'عدد المدعوين',
        'الميزانية',
        'عدد الخدمات',
        'إجمالي التكلفة',
        'المدفوع',
        'المتبقي',
        'الحالة',
      ],
      rows: all.rows.map((plan) => [
        plan.title,
        plan.user_name,
        formatDate(plan.wedding_date),
        plan.governorate,
        plan.guests_count,
        plan.budget,
        plan.services_count,
        plan.total_cost,
        plan.paid_amount,
        plan.remaining_amount,
        PLAN_STATUS_LABEL[plan.status],
      ]),
    }
  }, [debouncedSearch, status, governorate])

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
            placeholder="ابحث باسم الخطة أو العميل…"
            aria-label="بحث في خطط الأعراس"
            className="ps-9"
          />
        </div>

        <div className="w-44">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as PlanStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(PLAN_STATUS_LABEL) as PlanStatus[]).map((key) => (
              <option key={key} value={key}>
                {PLAN_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-40">
          <Select
            value={governorate}
            onChange={(event) => setGovernorate(event.target.value)}
            aria-label="تصفية حسب المحافظة"
          >
            <option value="all">كل المحافظات</option>
            {GOVERNORATES.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-خطط-الأعراس"
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
            title="لا توجد خطط"
            description="جرّب تعديل كلمات البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {[
                    'الخطة',
                    'تاريخ العرس',
                    'المدعوون',
                    'الخدمات',
                    'الميزانية',
                    'التكلفة',
                    'المتبقي',
                    'الحالة',
                  ].map((heading) => (
                    <th
                      key={heading}
                      scope="col"
                      className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((plan) => {
                  // Over budget is the one number an admin needs to spot at a glance.
                  const overBudget = plan.budget > 0 && plan.total_cost > plan.budget
                  return (
                    <tr
                      key={plan.id}
                      className="border-b border-hairline last:border-0 hover:bg-surface-2"
                    >
                      <td className="px-4 py-3">
                        <Link
                          to={`/plans/${plan.id}`}
                          className="font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                        >
                          {plan.title}
                        </Link>
                        <p className="text-xs text-muted">
                          {plan.user_name} · {plan.governorate}
                        </p>
                      </td>
                      <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatDate(plan.wedding_date)}
                        <span className="block text-[11px] text-muted">
                          {countdown(plan.wedding_date)}
                        </span>
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(plan.guests_count)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(plan.services_count)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(plan.budget)}
                      </td>
                      <td
                        className={cn(
                          'tnum px-4 py-3 text-xs whitespace-nowrap',
                          overBudget ? 'font-medium text-[var(--critical)]' : 'text-ink-2',
                        )}
                        title={overBudget ? 'تجاوزت التكلفة الميزانية المعلنة' : undefined}
                      >
                        {formatMoney(plan.total_cost)}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(plan.remaining_amount)}
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone={PLAN_STATUS_TONE[plan.status]}>
                          {PLAN_STATUS_LABEL[plan.status]}
                        </Badge>
                      </td>
                    </tr>
                  )
                })}
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
