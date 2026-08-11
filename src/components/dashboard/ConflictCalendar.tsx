import { useCallback, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { AlertTriangle, ChevronLeft, ChevronRight } from 'lucide-react'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatNumber, formatTime } from '@/lib/format'
import { getCalendar } from '@/services/bookings'

const WEEKDAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']

const monthLabel = new Intl.DateTimeFormat('ar-EG-u-nu-latn-ca-gregory', {
  month: 'long',
  year: 'numeric',
})

const isoDay = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/**
 * Month grid of upcoming bookings, marking the days where one provider is
 * committed twice.
 *
 * A double-booked provider is the failure this platform cannot recover from —
 * the wedding happens once — so it is surfaced on the dashboard rather than
 * waiting to be discovered inside a booking record.
 */
export function ConflictCalendar() {
  const [offset, setOffset] = useState(0)
  const load = useCallback(() => getCalendar(90), [])
  const { data, error, loading, reload } = useAsync(load, [])

  const month = useMemo(() => {
    const base = new Date()
    return new Date(base.getFullYear(), base.getMonth() + offset, 1)
  }, [offset])

  const byDate = useMemo(
    () => new Map((data ?? []).map((day) => [day.date, day])),
    [data],
  )

  // Leading blanks so the 1st lands under its weekday column.
  const firstWeekday = month.getDay()
  const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
  const cells: (string | null)[] = [
    ...Array.from({ length: firstWeekday }, () => null),
    ...Array.from({ length: daysInMonth }, (_, i) =>
      isoDay(new Date(month.getFullYear(), month.getMonth(), i + 1)),
    ),
  ]

  const today = isoDay(new Date())
  const monthKey = isoDay(month).slice(0, 7)
  const allConflicts = (data ?? []).flatMap((day) => day.conflicts)
  const monthConflicts = allConflicts.filter((conflict) =>
    conflict.event_date.startsWith(monthKey),
  )
  // A quiet month is not a quiet quarter: say where the rest are.
  const elsewhere = allConflicts.length - monthConflicts.length

  return (
    <Card>
      <CardHeader
        title="مراقب تضارب المواعيد"
        subtitle="تقويم الحجوزات القادمة — تُعلَّم الأيام التي ارتبط فيها مقدّم خدمة بموعدين"
        actions={
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setOffset((value) => value - 1)}
              aria-label="الشهر السابق"
              className="cursor-pointer rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-ink"
            >
              {/* Under RTL "previous" points toward the start edge, the right. */}
              <ChevronRight size={15} aria-hidden />
            </button>
            <span className="min-w-28 text-center text-xs font-medium text-ink">
              {monthLabel.format(month)}
            </span>
            <button
              type="button"
              onClick={() => setOffset((value) => value + 1)}
              aria-label="الشهر التالي"
              className="cursor-pointer rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-ink"
            >
              <ChevronLeft size={15} aria-hidden />
            </button>
          </div>
        }
      />

      {loading ? (
        <LoadingBlock />
      ) : error && !data ? (
        <ErrorState message={error} onRetry={reload} />
      ) : (
        <CardBody className="flex flex-col gap-4">
          <div>
            <div className="grid grid-cols-7 gap-1 pb-1">
              {WEEKDAYS.map((day) => (
                <span key={day} className="text-center text-[11px] text-muted">
                  {day}
                </span>
              ))}
            </div>

            <div className="grid grid-cols-7 gap-1">
              {cells.map((date, index) => {
                if (!date) return <span key={`blank-${index}`} aria-hidden />
                const day = byDate.get(date)
                const count = day?.bookings.length ?? 0
                const clash = (day?.conflicts.length ?? 0) > 0
                return (
                  <div
                    key={date}
                    title={
                      count === 0
                        ? undefined
                        : `${formatDate(date)}: ${formatNumber(count)} حجز${clash ? ' — تضارب' : ''}`
                    }
                    className={cn(
                      'flex h-12 flex-col items-center justify-center gap-1 rounded-lg border text-xs',
                      date === today
                        ? 'border-accent text-ink'
                        : count > 0
                          ? 'border-hairline bg-surface-2 text-ink'
                          : 'border-transparent text-muted',
                    )}
                  >
                    <span className="tnum">{Number(date.slice(8))}</span>
                    {count > 0 ? (
                      <span className="flex items-center gap-0.5">
                        {/* Shape, not colour alone: a clash gets its own glyph. */}
                        {clash ? (
                          <AlertTriangle
                            size={10}
                            aria-hidden
                            style={{ color: 'var(--critical)' }}
                          />
                        ) : null}
                        <span
                          aria-hidden
                          className="h-1.5 w-1.5 rounded-full"
                          style={{ background: clash ? 'var(--critical)' : 'var(--accent)' }}
                        />
                      </span>
                    ) : null}
                  </div>
                )
              })}
            </div>
          </div>

          {monthConflicts.length === 0 ? (
            <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs text-ink-2">
              لا يوجد تضارب في مواعيد هذا الشهر.
              {elsewhere > 0 ? (
                <>
                  {' '}
                  يوجد {formatNumber(elsewhere)} تضارب في أشهر أخرى —{' '}
                  <button
                    type="button"
                    onClick={() => setOffset((value) => value + 1)}
                    className="cursor-pointer font-medium text-accent underline underline-offset-4"
                  >
                    تصفَّح الأشهر التالية
                  </button>
                  .
                </>
              ) : null}
            </p>
          ) : (
            <ul className="flex flex-col gap-2">
              {monthConflicts.map((conflict) => (
                <li
                  key={`${conflict.provider_id}-${conflict.event_date}`}
                  className="rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2.5"
                >
                  <p className="flex items-center gap-1.5 text-xs font-medium text-ink">
                    <AlertTriangle size={13} aria-hidden style={{ color: 'var(--critical)' }} />
                    <Link
                      to={`/providers/${conflict.provider_id}`}
                      className="underline-offset-4 hover:text-accent hover:underline"
                    >
                      {conflict.provider_name}
                    </Link>
                    <span className="font-normal text-muted">— {formatDate(conflict.event_date)}</span>
                  </p>
                  <ul className="mt-1.5 flex flex-col gap-1">
                    {conflict.bookings.map((booking) => (
                      <li key={booking.id} className="text-[11px] text-ink-2">
                        <Link
                          to={`/bookings/${booking.id}`}
                          className="underline-offset-4 hover:text-accent hover:underline"
                        >
                          <span dir="ltr" className="tnum">
                            {booking.reference}
                          </span>
                        </Link>
                        {' · '}
                        {formatTime(booking.event_time)} · {booking.service_title}
                      </li>
                    ))}
                  </ul>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      )}
    </Card>
  )
}
