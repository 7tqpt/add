import { useCallback, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Activity,
  Banknote,
  BriefcaseBusiness,
  CalendarCheck,
  ChevronLeft,
  PercentCircle,
  RefreshCw,
  LifeBuoy,
  Scale,
  Star,
  Wallet,
  type LucideIcon,
} from 'lucide-react'
import { BarChart } from '@/components/charts/BarChart'
import { ConflictCalendar } from '@/components/dashboard/ConflictCalendar'
import { PaymentsFeed } from '@/components/dashboard/PaymentsFeed'
import { ProviderQueue } from '@/components/dashboard/ProviderQueue'
import { ChartCard } from '@/components/charts/ChartCard'
import { SERIES_COLORS } from '@/components/charts/chart-utils'
import { StatTile } from '@/components/charts/StatTile'
import { TimeSeriesChart } from '@/components/charts/TimeSeriesChart'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import {
  PLATFORM_LABEL,
  formatCompact,
  formatDate,
  formatMoney,
  formatMoneyCompact,
  formatNumber,
} from '@/lib/format'
import type { DashboardStats, RangeDays } from '@/lib/types'
import { getDashboardStats } from '@/services/stats'

const RANGES: { value: RangeDays; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
]

const COMPARISON = 'مقارنة بالفترة السابقة'

/** What is waiting on an admin right now, and where to go to clear it. */
const QUEUE: { key: keyof DashboardStats; label: string; to: string; icon: LucideIcon }[] = [
  { key: 'pendingProviders', label: 'طلبات توثيق', to: '/providers', icon: BriefcaseBusiness },
  { key: 'openTickets', label: 'تذاكر خدمة العملاء', to: '/support', icon: LifeBuoy },
  { key: 'openDisputes', label: 'نزاعات مفتوحة', to: '/disputes', icon: Scale },
  { key: 'pendingSettlements', label: 'تسويات بانتظار الاعتماد', to: '/settlements', icon: Banknote },
  { key: 'flaggedReviews', label: 'تقييمات مُبلَّغ عنها', to: '/reviews', icon: Star },
]

export function DashboardPage() {
  const [range, setRange] = useState<RangeDays>(30)
  const load = useCallback(() => getDashboardStats(range), [range])
  const { data, error, loading, refetching, reload } = useAsync(load, [range])

  if (loading) return <LoadingBlock />
  if (error && !data) return <ErrorState message={error} onRetry={reload} />
  if (!data) return null

  const bookingPoints = data.bookingsByDay.map((point) => ({
    date: point.date,
    values: [point.value],
  }))

  const installPoints = data.installsByDay.map((day) => ({
    date: day.date,
    values: [day.ios, day.android],
  }))
  const installSeries = [
    { label: PLATFORM_LABEL.ios, color: SERIES_COLORS[0] },
    { label: PLATFORM_LABEL.android, color: SERIES_COLORS[1] },
  ]

  return (
    <div className="flex flex-col gap-4">
      {/* One filter row above everything it scopes — never per-card filters. */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="group"
          aria-label="الفترة الزمنية"
          className="inline-flex rounded-lg border border-hairline bg-surface p-0.5"
        >
          {RANGES.map((option) => (
            <button
              key={option.value}
              type="button"
              onClick={() => setRange(option.value)}
              aria-pressed={range === option.value}
              className={cn(
                'h-8 cursor-pointer rounded-md px-3 text-xs font-medium transition-colors',
                range === option.value ? 'bg-surface-2 text-ink' : 'text-muted hover:text-ink',
              )}
            >
              {option.label}
            </button>
          ))}
        </div>

        <button
          type="button"
          onClick={reload}
          disabled={refetching}
          className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-lg border border-hairline bg-surface px-3 text-xs font-medium text-ink-2 transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-55"
        >
          <RefreshCw size={13} aria-hidden className={refetching ? 'animate-spin' : undefined} />
          تحديث
        </button>
      </div>

      {error ? (
        <p
          role="alert"
          className="rounded-lg border border-hairline bg-surface px-3 py-2 text-xs text-ink"
        >
          تعذّر تحديث البيانات ({error}) — الأرقام المعروضة من آخر تحميل ناجح.
        </p>
      ) : null}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          label="الحجوزات"
          value={formatNumber(data.bookings.value)}
          change={data.bookings.change}
          comparisonLabel={COMPARISON}
          icon={CalendarCheck}
          refetching={refetching}
        />
        <StatTile
          label="قيمة الحجوزات"
          value={formatMoneyCompact(data.revenue.value)}
          valueTitle={formatMoney(data.revenue.value)}
          change={data.revenue.change}
          comparisonLabel={COMPARISON}
          icon={Wallet}
          refetching={refetching}
        />
        <StatTile
          label="عمولة المنصة"
          value={formatMoneyCompact(data.commission.value)}
          valueTitle={formatMoney(data.commission.value)}
          change={data.commission.change}
          comparisonLabel={COMPARISON}
          icon={PercentCircle}
          refetching={refetching}
        />
        <StatTile
          label="متوسط المستخدمين النشطين يومياً"
          value={formatNumber(data.activeUsers.value)}
          change={data.activeUsers.change}
          comparisonLabel={COMPARISON}
          icon={Activity}
          refetching={refetching}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <ProviderQueue />
        </div>
        <PaymentsFeed />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <ConflictCalendar />
        </div>

        <Card>
          <CardHeader title="بانتظار الإدارة" subtitle="ما يحتاج قراراً الآن" />
          <CardBody className="flex flex-col gap-1 px-2 py-2 sm:px-2">
            {QUEUE.map((entry) => {
              const count = data[entry.key] as number
              return (
                <Link
                  key={entry.key}
                  to={entry.to}
                  className="flex items-center justify-between gap-3 rounded-lg px-3 py-2.5 transition-colors hover:bg-surface-2"
                >
                  <span className="flex min-w-0 items-center gap-2.5">
                    <entry.icon
                      size={16}
                      aria-hidden
                      className={count > 0 ? 'text-accent' : 'text-muted'}
                    />
                    <span className="truncate text-xs text-ink-2">{entry.label}</span>
                  </span>
                  <span className="flex shrink-0 items-center gap-1">
                    {/* Zero is not dimmed away: "nothing waiting" is the answer
                        an admin came here for. */}
                    <span
                      className={cn(
                        'tnum text-sm font-semibold',
                        count > 0 ? 'text-ink' : 'text-muted',
                      )}
                    >
                      {formatNumber(count)}
                    </span>
                    <ChevronLeft size={14} aria-hidden className="text-muted" />
                  </span>
                </Link>
              )
            })}
          </CardBody>
        </Card>
      </div>

      <ChartCard
        title="الحجوزات اليومية"
        subtitle="الحجوزات القائمة والمنفّذة — المحور الأفقي يبدأ من الأقدم على اليمين"
        refetching={refetching}
        table={{
          columns: ['التاريخ', 'الحجوزات'],
          rows: [...data.bookingsByDay]
            .reverse()
            .map((point) => [formatDate(point.date), formatNumber(point.value)]),
        }}
      >
        <TimeSeriesChart
          points={bookingPoints}
          series={[{ label: 'الحجوزات', color: SERIES_COLORS[0] }]}
          fill
          formatValue={formatNumber}
          formatTick={formatCompact}
        />
      </ChartCard>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader title="الحجوزات حسب القسم" subtitle="أكثر الخدمات طلباً في الفترة" />
          <CardBody>
            <BarChart
              data={data.bookingsByCategory.map((row) => ({
                label: row.category,
                value: row.count,
              }))}
              formatValue={formatNumber}
            />
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="أعلى المحافظات" subtitle="حسب عدد الحجوزات" />
          <CardBody>
            <BarChart
              data={data.topGovernorates.map((row) => ({
                label: row.governorate,
                value: row.bookings,
              }))}
              formatValue={formatNumber}
            />
          </CardBody>
        </Card>
      </div>

      <ChartCard
        title="عمليات التثبيت اليومية"
        subtitle="حسب المنصة — نمو قاعدة المستخدمين خلف الحجوزات"
        series={installSeries}
        refetching={refetching}
        table={{
          columns: ['التاريخ', PLATFORM_LABEL.ios, PLATFORM_LABEL.android],
          rows: [...data.installsByDay]
            .reverse()
            .map((day) => [
              formatDate(day.date),
              formatNumber(day.ios),
              formatNumber(day.android),
            ]),
        }}
      >
        <TimeSeriesChart
          points={installPoints}
          series={installSeries}
          formatValue={formatNumber}
          formatTick={formatCompact}
        />
      </ChartCard>
    </div>
  )
}
