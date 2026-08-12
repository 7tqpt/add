import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { AlertTriangle, CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { BOOKING_FORMS, formatCount, formatDate, formatTime } from '@/lib/format'
import type { Booking, BookingStatus } from '@/lib/types'
import { BOOKING_STATUS_LABEL, getCalendar, type CalendarDay } from '@/services/bookings'

const WEEKDAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']

const monthLabel = new Intl.DateTimeFormat('ar-EG-u-nu-latn-ca-gregory', {
  month: 'long',
  year: 'numeric',
})

const dayLabel = new Intl.DateTimeFormat('ar-EG-u-nu-latn-ca-gregory', {
  day: 'numeric',
  month: 'long',
})

const isoDay = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/** الحالات الثلاث التي يعلّمها التقويم، مرتّبة بالأهمية. */
type DayMark = 'conflict' | 'pending' | 'confirmed'

const MARK_COLOR: Record<DayMark, string> = {
  conflict: 'var(--critical)',
  pending: 'var(--text-muted)',
  confirmed: 'var(--accent)',
}

const LEGEND: { mark: DayMark; label: string }[] = [
  { mark: 'confirmed', label: 'حجز مؤكد' },
  { mark: 'pending', label: 'بانتظار مقدّم الخدمة' },
  { mark: 'conflict', label: 'تعارض يتطلّب فكّ التشابك' },
]

/** حجز ينتظر ردّ مقدّم الخدمة ليس «جيداً» بعد — لونه ينتظر معه. */
const STATUS_TONE: Partial<Record<BookingStatus, Tone>> = {
  confirmed: 'good',
  pending_provider: 'warning',
  completed: 'good',
}

/** ما يميّز اليوم في الشبكة: نقطة لكل حالة موجودة فيه، لا أكثر. */
function marksOf(day: CalendarDay | undefined): DayMark[] {
  if (!day || day.bookings.length === 0) return []
  const marks: DayMark[] = []
  if (day.conflicts.length > 0) marks.push('conflict')
  if (day.bookings.some((b) => b.status === 'pending_provider')) marks.push('pending')
  if (day.bookings.some((b) => b.status === 'confirmed')) marks.push('confirmed')
  return marks
}

/**
 * تقويم شهري للحجوزات القادمة، يعلّم الأيام التي ارتبط فيها مقدّم خدمة بموعدين.
 *
 * الحجز المزدوج هو العطل الذي لا تُصلحه المنصة بعد وقوعه — العرس يقع مرة
 * واحدة — فيُعرض على الصفحة الأولى بدل أن يُكتشف داخل سجلّ حجز.
 *
 * اليوم المختار يبدأ عند أقرب تعارض لا عند اليوم الحالي: الشاشة موجودة لتُري
 * المشكلة، فتفتح عليها.
 */
export function ConflictCalendar() {
  /**
   * الشهر المعروض حالة مستقلّة لا محسوبة من اليوم المختار.
   *
   * الاشتقاق يبدو أوجز لكنه يجعل الاختيار يحرّك الشهر: تتصفّح إلى الشهر التالي،
   * فتضغط يوماً فيه، فيصير هو الأساس ويُضاف إليه الإزاحة نفسها — فيقفز التقويم
   * شهراً آخر تحت يدك.
   */
  const [anchor, setAnchor] = useState(() => {
    const now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), 1)
  })
  const [selected, setSelected] = useState<string | null>(null)
  const load = useCallback(() => getCalendar(90), [])
  const { data, error, loading, reload } = useAsync(load, [])

  const days = useMemo(() => data ?? [], [data])
  const byDate = useMemo(() => new Map(days.map((day) => [day.date, day])), [days])

  const firstConflictDate = useMemo(
    () => days.find((day) => day.conflicts.length > 0)?.date ?? null,
    [days],
  )

  /** ينقل الاختيار والشهر معاً — الذهاب إلى يوم لا معنى له إن بقي مخفياً. */
  const goTo = useCallback((date: string) => {
    setSelected(date)
    const target = new Date(`${date}T00:00:00`)
    setAnchor(new Date(target.getFullYear(), target.getMonth(), 1))
  }, [])

  // يُضبط مرة عند وصول البيانات فقط، فلا يقفز الاختيار من تحت يد المستخدم.
  useEffect(() => {
    if (!data || selected) return
    goTo(firstConflictDate ?? isoDay(new Date()))
  }, [data, firstConflictDate, selected, goTo])

  const firstWeekday = anchor.getDay()
  const daysInMonth = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0).getDate()
  const cells: (string | null)[] = [
    ...Array.from({ length: firstWeekday }, () => null),
    ...Array.from({ length: daysInMonth }, (_, i) =>
      isoDay(new Date(anchor.getFullYear(), anchor.getMonth(), i + 1)),
    ),
  ]

  const today = isoDay(new Date())
  const monthKey = isoDay(anchor).slice(0, 7)
  const totalConflicts = days.reduce((sum, day) => sum + day.conflicts.length, 0)
  const monthConflicts = days
    .filter((day) => day.date.startsWith(monthKey))
    .reduce((sum, day) => sum + day.conflicts.length, 0)

  const selectedDay = selected ? byDate.get(selected) : undefined
  const selectedBookings = [...(selectedDay?.bookings ?? [])].sort((a, b) =>
    (a.event_time ?? '').localeCompare(b.event_time ?? ''),
  )

  /** الحجوزات المتشابكة في اليوم المختار، مفتاحها معرّف الحجز. */
  const clashing = useMemo(() => {
    const map = new Map<string, Booking[]>()
    for (const conflict of selectedDay?.conflicts ?? []) {
      for (const booking of conflict.bookings) {
        map.set(
          booking.id,
          conflict.bookings.filter((other) => other.id !== booking.id),
        )
      }
    }
    return map
  }, [selectedDay])

  return (
    <Card>
      <CardHeader
        title={
          <span className="flex items-center gap-2">
            <CalendarDays size={16} aria-hidden className="text-accent" />
            مراقب تضارب الحجوزات
          </span>
        }
        subtitle="تقويم الحجوزات القادمة — تُعلَّم الأيام التي ارتبط فيها مقدّم خدمة بموعدين"
        actions={
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setAnchor((m) => new Date(m.getFullYear(), m.getMonth() - 1, 1))}
              aria-label="الشهر السابق"
              className="cursor-pointer rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-ink"
            >
              {/* Under RTL "previous" points toward the start edge, the right. */}
              <ChevronRight size={15} aria-hidden />
            </button>
            <span className="min-w-28 text-center text-xs font-medium text-ink">
              {monthLabel.format(anchor)}
            </span>
            <button
              type="button"
              onClick={() => setAnchor((m) => new Date(m.getFullYear(), m.getMonth() + 1, 1))}
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
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_17rem]">
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
                  const marks = marksOf(day)
                  const count = day?.bookings.length ?? 0
                  const isSelected = date === selected
                  return (
                    <button
                      key={date}
                      type="button"
                      aria-pressed={isSelected}
                      aria-label={`${formatDate(date)}${count ? ` — ${formatCount(count, BOOKING_FORMS)}` : ''}`}
                      onClick={() => setSelected(date)}
                      className={cn(
                        'flex h-12 cursor-pointer flex-col items-center justify-center gap-1 rounded-lg border text-xs transition-colors',
                        isSelected
                          ? 'border-accent bg-[color-mix(in_oklab,var(--accent)_10%,transparent)] text-ink'
                          : date === today
                            ? 'border-accent text-ink'
                            : count > 0
                              ? 'border-hairline bg-surface-2 text-ink hover:border-accent'
                              : 'border-transparent text-muted hover:bg-surface-2',
                      )}
                    >
                      <span className="tnum">{Number(date.slice(8))}</span>
                      <span className="flex items-center gap-0.5">
                        {marks.map((mark) => (
                          <span
                            key={mark}
                            aria-hidden
                            className="h-1.5 w-1.5 rounded-full"
                            style={{ background: MARK_COLOR[mark] }}
                          />
                        ))}
                      </span>
                    </button>
                  )
                })}
              </div>

              <ul className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1.5">
                {LEGEND.map((item) => (
                  <li key={item.mark} className="flex items-center gap-1.5 text-[11px] text-muted">
                    <span
                      aria-hidden
                      className="h-1.5 w-1.5 rounded-full"
                      style={{ background: MARK_COLOR[item.mark] }}
                    />
                    {item.label}
                  </li>
                ))}
              </ul>
            </div>

            {/* تفاصيل اليوم المختار */}
            <div className="rounded-lg border border-hairline bg-surface-2 p-3">
              <div className="flex items-baseline justify-between gap-2">
                <p className="text-xs font-medium text-ink">
                  {selected ? dayLabel.format(new Date(`${selected}T00:00:00`)) : '—'}
                </p>
                <p className="text-[11px] text-muted">
                  {selectedBookings.length > 0
                    ? formatCount(selectedBookings.length, BOOKING_FORMS)
                    : 'لا حجوزات'}
                </p>
              </div>

              {selectedBookings.length === 0 ? (
                <p className="mt-3 text-[11px] text-muted">لا توجد حجوزات في هذا اليوم.</p>
              ) : (
                <ul className="mt-3 flex flex-col gap-2">
                  {selectedBookings.map((booking) => {
                    const others = clashing.get(booking.id) ?? []
                    return (
                      <li
                        key={booking.id}
                        className={cn(
                          'rounded-lg border px-2.5 py-2',
                          others.length > 0
                            ? 'border-[color-mix(in_oklab,var(--critical)_35%,transparent)] bg-[color-mix(in_oklab,var(--critical)_7%,transparent)]'
                            : 'border-hairline bg-surface',
                        )}
                      >
                        <div className="flex items-center justify-between gap-2">
                          <Badge
                            tone={
                              others.length > 0
                                ? 'critical'
                                : (STATUS_TONE[booking.status] ?? 'neutral')
                            }
                            icon={others.length > 0}
                          >
                            {others.length > 0 ? 'تعارض' : BOOKING_STATUS_LABEL[booking.status]}
                          </Badge>
                          <span className="tnum text-[11px] text-muted">
                            {booking.event_time ? formatTime(booking.event_time) : '—'}
                          </span>
                        </div>

                        <Link
                          to={`/bookings/${booking.id}`}
                          className="mt-1 block text-[11px] font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                        >
                          {booking.service_title} — {booking.user_name}
                        </Link>
                        <p className="text-[11px] text-muted">{booking.provider_name}</p>

                        {others.map((other) => (
                          <p
                            key={other.id}
                            className="mt-1.5 flex items-start gap-1 text-[11px] text-[var(--critical)]"
                          >
                            <AlertTriangle size={11} aria-hidden className="mt-0.5 shrink-0" />
                            <span>
                              {booking.provider_name} محجوز أيضاً:{' '}
                              {other.event_time ? `${formatTime(other.event_time)} — ` : ''}
                              {other.user_name}
                            </span>
                          </p>
                        ))}
                      </li>
                    )
                  })}
                </ul>
              )}

              <Link
                to="/bookings"
                className="mt-3 flex h-9 items-center justify-center rounded-lg bg-accent px-3 text-xs font-medium text-accent-ink hover:brightness-110"
              >
                فتح جدول الحجوزات
              </Link>
            </div>
          </div>

          {monthConflicts === 0 ? (
            <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs text-ink-2">
              لا يوجد تضارب في مواعيد هذا الشهر.
              {totalConflicts > 0 && firstConflictDate ? (
                <>
                  {' '}
                  أقرب تعارض في {formatDate(firstConflictDate)} —{' '}
                  <button
                    type="button"
                    onClick={() => goTo(firstConflictDate)}
                    className="cursor-pointer font-medium text-accent underline underline-offset-4"
                  >
                    اذهب إليه
                  </button>
                  .
                </>
              ) : null}
            </p>
          ) : null}
        </CardBody>
      )}
    </Card>
  )
}
