import { useCallback, useState } from 'react'
import { Activity, Download, RefreshCw, ShieldCheck, TrendingUp, Wallet } from 'lucide-react'
import { BarChart } from '@/components/charts/BarChart'
import { ChartCard } from '@/components/charts/ChartCard'
import { SERIES_COLORS } from '@/components/charts/chart-utils'
import { ShareBar } from '@/components/charts/ShareBar'
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
  formatNumber,
  formatPercent,
} from '@/lib/format'
import type { RangeDays } from '@/lib/types'
import { getDashboardStats } from '@/services/stats'

const RANGES: { value: RangeDays; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
]

const COMPARISON = 'مقارنة بالفترة السابقة'

export function DashboardPage() {
  const [range, setRange] = useState<RangeDays>(30)
  const load = useCallback(() => getDashboardStats(range), [range])
  const { data, error, loading, refetching, reload } = useAsync(load, [range])

  if (loading) return <LoadingBlock />
  if (error && !data) return <ErrorState message={error} onRetry={reload} />
  if (!data) return null

  const installPoints = data.installsByDay.map((day) => ({
    date: day.date,
    values: [day.ios, day.android],
  }))
  const installSeries = [
    { label: PLATFORM_LABEL.ios, color: SERIES_COLORS[0] },
    { label: PLATFORM_LABEL.android, color: SERIES_COLORS[1] },
  ]

  const sessionPoints = data.sessionsByDay.map((point) => ({
    date: point.date,
    values: [point.value],
  }))

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
                range === option.value
                  ? 'bg-surface-2 text-ink'
                  : 'text-muted hover:text-ink',
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
        <p role="alert" className="rounded-lg border border-hairline bg-surface px-3 py-2 text-xs text-ink">
          تعذّر تحديث البيانات ({error}) — الأرقام المعروضة من آخر تحميل ناجح.
        </p>
      ) : null}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          label="متوسط المستخدمين النشطين يومياً"
          value={formatNumber(data.activeUsers.value)}
          change={data.activeUsers.change}
          comparisonLabel={COMPARISON}
          icon={Activity}
          refetching={refetching}
        />
        <StatTile
          label="عمليات التثبيت"
          value={formatNumber(data.installs.value)}
          change={data.installs.change}
          comparisonLabel={COMPARISON}
          icon={Download}
          refetching={refetching}
        />
        <StatTile
          label="الجلسات"
          value={formatNumber(data.sessions.value)}
          change={data.sessions.change}
          comparisonLabel={COMPARISON}
          icon={TrendingUp}
          refetching={refetching}
        />
        <StatTile
          label="الإيرادات"
          value={formatMoney(data.revenue.value)}
          change={data.revenue.change}
          comparisonLabel={COMPARISON}
          icon={Wallet}
          refetching={refetching}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <ChartCard
            title="عمليات التثبيت اليومية"
            subtitle="حسب المنصة — المحور الأفقي يبدأ من الأقدم على اليمين"
            series={installSeries}
            refetching={refetching}
            table={{
              columns: ['التاريخ', PLATFORM_LABEL.ios, PLATFORM_LABEL.android],
              rows: [...data.installsByDay]
                .reverse()
                .map((day) => [formatDate(day.date), formatNumber(day.ios), formatNumber(day.android)]),
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

        <div className="flex flex-col gap-4">
          <Card>
            <CardHeader title="توزيع قاعدة المستخدمين" subtitle="حسب المنصة" />
            <CardBody>
              <ShareBar
                segments={data.platformSplit.map((entry, index) => ({
                  label: PLATFORM_LABEL[entry.platform] ?? entry.platform,
                  value: entry.users,
                  color: SERIES_COLORS[index],
                }))}
              />
            </CardBody>
          </Card>

          <StatTile
            label="معدل الجلسات الخالية من الأعطال"
            value={Number.isFinite(data.crashFreeRate) ? formatPercent(data.crashFreeRate) : '—'}
            icon={ShieldCheck}
            refetching={refetching}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <ChartCard
            title="الجلسات اليومية"
            subtitle="إجمالي الجلسات على كل المنصات"
            refetching={refetching}
            table={{
              columns: ['التاريخ', 'الجلسات'],
              rows: [...data.sessionsByDay]
                .reverse()
                .map((point) => [formatDate(point.date), formatNumber(point.value)]),
            }}
          >
            <TimeSeriesChart
              points={sessionPoints}
              series={[{ label: 'الجلسات', color: SERIES_COLORS[0] }]}
              fill
              formatValue={formatNumber}
              formatTick={formatCompact}
            />
          </ChartCard>
        </div>

        <Card>
          <CardHeader title="أعلى الدول" subtitle="حسب عدد المستخدمين" />
          <CardBody>
            <BarChart data={data.topCountries.map((row) => ({ label: row.country, value: row.users }))} formatValue={formatNumber} />
          </CardBody>
        </Card>
      </div>
    </div>
  )
}
