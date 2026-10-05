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
import { RecentBookings } from '@/components/dashboard/RecentBookings'
import { ChartCard } from '@/components/charts/ChartCard'
import { SERIES_COLORS } from '@/components/charts/chart-utils'
import { StatTile, type Tone, toneChip } from '@/components/charts/StatTile'
import { TimeSeriesChart } from '@/components/charts/TimeSeriesChart'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import {
  PLATFORM_LABEL,
  formatCompact,
  formatDate,
  formatDelta,
  formatMoney,
  formatMoneyCompact,
  formatNumber,
} from '@/lib/format'
import type { DashboardStats, PlatformIncome, RangeDays } from '@/lib/types'
import { getDashboardStats } from '@/services/stats'

const RANGES: { value: RangeDays; label: string }[] = [
  { value: 7, label: 'آخر 7 أيام' },
  { value: 30, label: 'آخر 30 يوماً' },
  { value: 90, label: 'آخر 90 يوماً' },
]

const COMPARISON = 'مقارنة بالفترة السابقة'

/** What is waiting on an admin right now, and where to go to clear it. */
const QUEUE: {
  key: keyof DashboardStats
  label: string
  to: string
  icon: LucideIcon
  tone: Tone
}[] = [
  { key: 'pendingProviders', label: 'طلبات توثيق', to: '/providers', icon: BriefcaseBusiness, tone: 'navy' },
  { key: 'openTickets', label: 'تذاكر خدمة العملاء', to: '/support', icon: LifeBuoy, tone: 'cyan' },
  { key: 'openDisputes', label: 'نزاعات مفتوحة', to: '/disputes', icon: Scale, tone: 'emerald' },
  { key: 'pendingSettlements', label: 'تسويات بانتظار الاعتماد', to: '/settlements', icon: Banknote, tone: 'azure' },
  { key: 'flaggedReviews', label: 'تقييمات مُبلَّغ عنها', to: '/reviews', icon: Star, tone: 'violet' },
]

export function DashboardPage() {
  const [range, setRange] = useState<RangeDays>(30)
  const [refreshKey, setRefreshKey] = useState(0)
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
      {/* (والعنوانُ والتحيّةُ في الرأس — `Topbar` — كما في صورة (أ).) */}
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
          onClick={() => { reload(); setRefreshKey((value) => value + 1) }}
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

      {/* ── أربعُ بطاقاتٍ بأقراصٍ ذهبيّة، كما في صورة (أ) ── */}
      <div data-kpis className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <ActionTile
          to="/bookings"
          icon={CalendarCheck}
          label="حجوزات الفترة"
          value={formatNumber(data.bookings.value)}
          note={`${formatDelta(data.bookings.change)} عن الفترة السابقة`}
        />
        <ActionTile
          to="/providers"
          icon={BriefcaseBusiness}
          label="طلبات توثيق"
          value={formatNumber(data.pendingProviders)}
          note="بانتظار مراجعة المستندات"
        />
        {/* **ما دخل الخزنة لا ما استُحقّ** — وإن لم تُشغَّل `income.sql` فالعمولة. */}
        <ActionTile
          to="/payments"
          icon={Wallet}
          label="إيراد المنصّة"
          value={formatMoneyCompact(data.income.available ? data.income.total : data.commission.value)}
          valueTitle={formatMoney(data.income.available ? data.income.total : data.commission.value)}
          note={data.income.available ? 'عمولاتٌ واشتراكاتٌ وإعلانات' : 'عمولةُ حجوزات الفترة'}
        />
        <ActionTile
          to="/support"
          icon={LifeBuoy}
          label="تذاكر مفتوحة"
          value={formatNumber(data.openTickets)}
          note="تنتظر ردّ خدمة العملاء"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2"><RecentBookings refreshKey={refreshKey} /></div>
        <div className="flex flex-col gap-4">
          <AdminQueue stats={data} />
          <PeriodBars points={data.bookingsByDay} />
        </div>
      </div>

      <details className="rounded-xl border border-hairline bg-surface p-3 sm:p-4">
        <summary className="cursor-pointer text-sm font-semibold text-ink">التحليلات والتقارير التفصيلية</summary>
        <div className="mt-4 flex flex-col gap-4">
      <div className="stagger grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          label="الحجوزات"
          tone="azure"
          value={formatNumber(data.bookings.value)}
          change={data.bookings.change}
          comparisonLabel={COMPARISON}
          icon={CalendarCheck}
          refetching={refetching}
        />
        <StatTile
          label="قيمة الحجوزات"
          tone="emerald"
          value={formatMoneyCompact(data.revenue.value)}
          valueTitle={formatMoney(data.revenue.value)}
          change={data.revenue.change}
          comparisonLabel={COMPARISON}
          icon={Wallet}
          refetching={refetching}
        />
        <StatTile
          label="عمولة المنصة"
          tone="navy"
          value={formatMoneyCompact(data.commission.value)}
          valueTitle={formatMoney(data.commission.value)}
          change={data.commission.change}
          comparisonLabel={COMPARISON}
          icon={PercentCircle}
          refetching={refetching}
        />
        <StatTile
          label="متوسط المستخدمين النشطين يومياً"
          tone="cyan"
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

      <IncomeCard income={data.income} />

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <ConflictCalendar />
        </div>
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
      </details>
    </div>
  )
}

/** بطاقةُ رقمٍ في صدر الصفحة: قرصٌ ذهبيٌّ بأيقونته، والرقمُ نبيذيٌّ كبير. */
function ActionTile({ to, icon: Icon, label, value, valueTitle, note }: {
  to: string
  icon: LucideIcon
  label: string
  value: string
  valueTitle?: string
  note: string
}) {
  return (
    <Link
      to={to}
      data-kpi
      className="lift flex items-start gap-3 rounded-2xl border border-hairline bg-surface px-4 py-4"
    >
      <span data-kpi-disc className="flex size-11 shrink-0 items-center justify-center rounded-full bg-gold-soft text-gold-ink">
        <Icon size={21} aria-hidden strokeWidth={1.8} />
      </span>
      <span className="min-w-0">
        <span className="block text-sm text-muted">{label}</span>
        <span className="block text-[1.6rem] font-bold leading-snug text-accent" title={valueTitle}>
          {value}
        </span>
        <span className="block truncate text-xs text-muted">{note}</span>
      </span>
    </Link>
  )
}

function AdminQueue({ stats }: { stats: DashboardStats }) {
  return (
    <Card>
      <CardHeader title="يحتاج إجراءك" />
      <CardBody className="flex flex-col px-0 py-0 sm:px-0">
        {QUEUE.map((entry) => {
          const count = stats[entry.key] as number
          return (
            <Link key={entry.key} to={entry.to}
              className="flex items-center justify-between gap-3 border-t border-hairline px-4 py-3 transition-colors hover:bg-surface-2">
              <span className="flex min-w-0 items-center gap-2.5">
                <entry.icon size={18} aria-hidden strokeWidth={1.8} className={count > 0 ? 'text-gold-ink' : 'text-muted'} />
                <span className="truncate text-sm text-ink-2">{entry.label}</span>
              </span>
              <span className="flex shrink-0 items-center gap-2">
                <span className={cn('tnum text-base font-bold', count > 0 ? 'text-accent' : 'text-muted')}>
                  {formatNumber(count)}
                </span>
                <ChevronLeft size={15} aria-hidden className="text-muted" />
              </span>
            </Link>
          )
        })}
      </CardBody>
    </Card>
  )
}

/**
 * أعمدةُ الحجوزات في الفترة — الآخرُ نبيذيٌّ والباقي ورديٌّ باهت، كما في
 * صورة (أ). **والأعمدةُ أيّامُ الفترة نفسُها** مجموعةً في اثني عشر عموداً على
 * الأكثر، لا أرقامٌ مرسومة: الرسمُ من `bookingsByDay`.
 */
function PeriodBars({ points }: { points: { date: string; value: number }[] }) {
  const groups = Math.min(12, points.length)
  if (groups === 0) return null
  const size = Math.ceil(points.length / groups)
  const bars: { from: string; to: string; value: number }[] = []
  for (let i = 0; i < points.length; i += size) {
    const chunk = points.slice(i, i + size)
    bars.push({ from: chunk[0].date, to: chunk[chunk.length - 1].date, value: chunk.reduce((n, p) => n + p.value, 0) })
  }
  const max = Math.max(1, ...bars.map((b) => b.value))
  return (
    <Card>
      <CardHeader title="الحجوزات في الفترة" />
      <CardBody>
        {/* الأقدمُ يميناً كقراءة السطر العربيّ. */}
        <div data-period-bars className="flex h-32 items-end gap-1.5" role="img" aria-label="الحجوزات في الفترة">
          {bars.map((bar, i) => (
            <span
              key={bar.from}
              title={`${formatDate(bar.from)} — ${formatDate(bar.to)}: ${formatNumber(bar.value)}`}
              className={cn('flex-1 rounded-md', i === bars.length - 1 ? 'bg-accent' : 'bg-[color-mix(in_oklab,var(--accent)_16%,var(--surface))]')}
              style={{ height: `${Math.max(6, Math.round((bar.value / max) * 100))}%` }}
            />
          ))}
        </div>
      </CardBody>
    </Card>
  )
}

/**
 * دخلُ المنصّة — ثلاثةُ أبوابٍ في رقمٍ واحد.
 *
 * **ولماذا بطاقةٌ مستقلّة عن «عمولة المنصة» أعلاه:** تلك عمولةٌ على حجوزاتٍ
 * **أُنشئت** في المدّة سواءٌ وصل مالُها أم لا، وهذه ما دخل الخزنة فعلاً.
 * وجمعُهما في رقمٍ واحد يخلط استحقاقاً بنقد، ويجعل الفرق بينهما — وهو أهمّ
 * ما في الصفحة لمن يخطّط إنفاقاً — غيرَ مرئيّ.
 *
 * وقد بُني بابان للدخل — الاشتراك والإعلان — ولم يكن في اللوحة مكانٌ
 * يعرضهما، فكان صاحبُ المنصّة يرى ثلثَ دخله ويظنّه كلَّه.
 */
function IncomeCard({ income }: { income: PlatformIncome }) {
  const streams: { label: string; value: number; tone: Tone }[] = [
    { label: 'عمولة محصَّلة', value: income.commission, tone: 'navy' },
    { label: 'اشتراكات المزوّدين', value: income.subscriptions, tone: 'emerald' },
    { label: 'إعلانات', value: income.promotions, tone: 'violet' },
  ]

  return (
    <Card>
      <CardHeader
        title="دخل المنصّة"
        subtitle="ما وصل الخزنة فعلاً في المدّة — لا ما استُحقّ"
      />
      <CardBody>
        {!income.available ? (
          /* قاعدةٌ أقدمُ من اللوحة: تنقص بطاقةٌ ولا تسقط صفحة. */
          <p className="text-sm text-muted">
            شغّل <code className="font-mono text-xs">income.sql</code> في محرّر SQL
            ليظهر دخل المنصّة هنا.
          </p>
        ) : (
          <div className="flex flex-col gap-4">
            <div>
              <p className="text-sm text-muted">المجموع</p>
              <p
                className="text-2xl font-semibold text-ink tabular-nums"
                title={formatMoney(income.total)}
              >
                {formatMoneyCompact(income.total)}
              </p>
            </div>
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {streams.map((stream) => (
                <div key={stream.label} className="rounded-lg bg-surface-2 px-3 py-2.5">
                  <span
                    style={toneChip(stream.tone)}
                    className="mb-1.5 inline-block h-1.5 w-6 rounded-full"
                  />
                  <p className="text-xs text-muted">{stream.label}</p>
                  <p
                    className="text-sm font-semibold text-ink tabular-nums"
                    title={formatMoney(stream.value)}
                  >
                    {formatMoneyCompact(stream.value)}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}
      </CardBody>
    </Card>
  )
}

