import { useCallback, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, Users } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { EmptyState, ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import {
  DAY_FORMS,
  formatCount,
  formatDate,
  formatMoney,
  formatNumber,
  formatTime,
} from '@/lib/format'
import { BOOKING_STATUS_LABEL } from '@/services/bookings'
import { PLAN_STATUS_LABEL, daysUntil, getPlan, listPlanBookings } from '@/services/plans'
import { BOOKING_STATUS_TONE } from './Bookings'
import { PLAN_STATUS_TONE } from './Plans'

export function PlanDetailPage() {
  const { id = '' } = useParams()

  const loadPlan = useCallback(() => getPlan(id), [id])
  const loadBookings = useCallback(() => listPlanBookings(id), [id])

  const plan = useAsync(loadPlan, [id])
  const bookings = useAsync(loadBookings, [id])

  if (plan.loading) return <LoadingBlock />
  if (plan.error && !plan.data) return <ErrorState message={plan.error} onRetry={plan.reload} />
  if (!plan.data) {
    return (
      <Card>
        <EmptyState
          title="الخطة غير موجودة"
          description="ربما حُذفت الخطة أو أن الرابط غير صحيح."
          action={
            <Link
              to="/plans"
              className="text-sm font-medium text-series-1 underline underline-offset-4"
            >
              العودة إلى الخطط
            </Link>
          }
        />
      </Card>
    )
  }

  const record = plan.data
  const rows = bookings.data ?? []
  const days = daysUntil(record.wedding_date)
  const overBudget = record.budget > 0 && record.total_cost > record.budget
  // A budget of zero means "not set", so the bar is only meaningful above it.
  const usage = record.budget > 0 ? Math.min(1, record.total_cost / record.budget) : 0

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/plans"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        <ArrowRight size={14} aria-hidden />
        كل الخطط
      </Link>

      <Card>
        <CardHeader
          title={record.title}
          subtitle={
            <Link
              to={`/users/${record.user_id}`}
              className="underline-offset-4 hover:text-series-1 hover:underline"
            >
              {record.user_name}
            </Link>
          }
          actions={
            <Badge tone={PLAN_STATUS_TONE[record.status]}>{PLAN_STATUS_LABEL[record.status]}</Badge>
          }
        />
        <CardBody className="flex flex-col gap-4">
          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-6">
            <Detail label="تاريخ العرس" value={formatDate(record.wedding_date)} />
            <Detail
              label="المتبقي على الموعد"
              value={days >= 0 ? formatCount(days, DAY_FORMS) : 'انقضى'}
            />
            <Detail label="المحافظة" value={record.governorate} />
            <Detail
              label="المدعوون"
              node={
                <span className="flex items-center gap-1.5">
                  <Users size={12} aria-hidden className="text-muted" />
                  {formatNumber(record.guests_count)}
                </span>
              }
            />
            <Detail label="الميزانية" value={formatMoney(record.budget)} />
            <Detail label="عدد الخدمات" value={formatNumber(record.services_count)} />
          </dl>

          {record.budget > 0 ? (
            <div>
              <div className="flex items-center justify-between gap-2 text-xs">
                <span className="text-ink-2">
                  التكلفة الحالية {formatMoney(record.total_cost)} من {formatMoney(record.budget)}
                </span>
                {overBudget ? (
                  <span className="font-medium text-[var(--critical)]">
                    تجاوز {formatMoney(record.total_cost - record.budget)}
                  </span>
                ) : null}
              </div>
              <div
                className="mt-1.5 h-2 overflow-hidden rounded-full bg-surface-2"
                role="img"
                aria-label={`استُهلك ${Math.round(usage * 100)}% من الميزانية`}
              >
                <div
                  className={cn('h-full rounded-full')}
                  style={{
                    width: `${usage * 100}%`,
                    background: overBudget ? 'var(--critical)' : 'var(--series-1)',
                  }}
                />
              </div>
            </div>
          ) : null}

          {record.notes ? (
            <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs leading-6 text-ink-2">
              {record.notes}
            </p>
          ) : null}
        </CardBody>
      </Card>

      <Card className={cn('overflow-hidden', bookings.refetching && 'is-refetching')}>
        <CardHeader
          title="خدمات هذه الخطة"
          subtitle={`مدفوع ${formatMoney(record.paid_amount)} · متبقٍ ${formatMoney(record.remaining_amount)}`}
        />
        {bookings.loading ? (
          <LoadingBlock />
        ) : bookings.error && !bookings.data ? (
          <ErrorState message={bookings.error} onRetry={bookings.reload} />
        ) : rows.length === 0 ? (
          <EmptyState
            title="لا توجد حجوزات بعد"
            description="لم يُضِف العميل أي خدمة إلى هذه الخطة."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr className="bg-surface-2">
                  {['الخدمة', 'مقدّم الخدمة', 'الموعد', 'الإجمالي', 'المدفوع', 'الحالة'].map(
                    (heading) => (
                      <th
                        key={heading}
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
                {rows.map((booking) => (
                  <tr key={booking.id} className="border-b border-hairline last:border-0">
                    <td className="px-4 py-2.5">
                      <Link
                        to={`/bookings/${booking.id}`}
                        className="font-medium text-ink underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {booking.service_title}
                      </Link>
                      <p className="text-[11px] text-muted">{booking.category_name}</p>
                    </td>
                    <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">
                      <Link
                        to={`/providers/${booking.provider_id}`}
                        className="underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {booking.provider_name}
                      </Link>
                    </td>
                    <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">
                      {formatDate(booking.event_date)}
                      <span className="tnum block text-[11px] text-muted">
                        {formatTime(booking.event_time)}
                      </span>
                    </td>
                    <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                      {formatMoney(booking.total_price)}
                    </td>
                    <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                      {formatMoney(booking.paid_amount)}
                    </td>
                    <td className="px-4 py-2.5">
                      <Badge tone={BOOKING_STATUS_TONE[booking.status]}>
                        {BOOKING_STATUS_LABEL[booking.status]}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
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
