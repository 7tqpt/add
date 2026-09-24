import { useCallback, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Card, CardHeader } from '@/components/ui/Card'
import { EmptyState, ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDate } from '@/lib/format'
import type { BookingStatus } from '@/lib/types'
import { BOOKING_STATUS_LABEL, listBookings, type BookingFilter } from '@/services/bookings'

const FILTERS: { value: BookingFilter; label: string }[] = [
  { value: 'all', label: 'الكل' },
  { value: 'pending_provider', label: 'بانتظار المزوّد' },
  { value: 'confirmed', label: 'مؤكد' },
  { value: 'cancelled', label: 'ملغي' },
]

const STATUS_TONE: Record<BookingStatus, Tone> = {
  pending_provider: 'warning',
  confirmed: 'good',
  completed: 'good',
  rejected: 'critical',
  cancelled: 'critical',
  expired: 'neutral',
}

/** Short actionable view of the real bookings, with server-side search and filters. */
export function RecentBookings({ refreshKey }: { refreshKey: number }) {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<BookingFilter>('all')
  const term = useDebounced(search)
  const load = useCallback(() => listBookings({
    search: term, status, category: 'all', governorate: 'all', days: 'all', page: 0, pageSize: 5,
  }), [term, status])
  const { data, error, loading, refetching, reload } = useAsync(load, [term, status, refreshKey])

  return (
    <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
      <CardHeader title="الحجوزات الأخيرة" subtitle="آخر خمس حجوزات بحسب البحث والحالة" actions={
        <Link to="/bookings" className="text-xs font-medium text-accent underline underline-offset-4">
          كل الحجوزات
        </Link>
      } />
      <div className="space-y-3 px-4 py-3 sm:px-5">
        <label className="relative block">
          <span className="sr-only">ابحث برقم الحجز أو اسم العميل</span>
          <Search size={17} aria-hidden className="absolute top-1/2 right-3 -translate-y-1/2 text-muted" />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="ابحث برقم الحجز أو اسم العميل"
            className="h-10 w-full rounded-lg border border-hairline bg-surface pe-3 ps-10 text-sm text-ink outline-none focus-visible:ring-2 focus-visible:ring-accent"
          />
        </label>
        <div role="group" aria-label="حالة الحجز" className="flex flex-wrap gap-1.5">
          {FILTERS.map((filter) => (
            <button
              key={filter.value}
              type="button"
              aria-pressed={status === filter.value}
              onClick={() => setStatus(filter.value)}
              className={cn('rounded-full border px-3 py-1.5 text-xs transition-colors',
                status === filter.value
                  ? 'border-accent bg-accent text-accent-ink'
                  : 'border-hairline bg-surface text-ink-2 hover:bg-surface-2')}
            >{filter.label}</button>
          ))}
        </div>
      </div>
      {loading ? <LoadingBlock /> : error && !data ? (
        <ErrorState message={error} onRetry={reload} />
      ) : !data || data.rows.length === 0 ? (
        <EmptyState title="لا توجد حجوزات مطابقة" />
      ) : (
        <div className="overflow-x-auto px-4 pb-4 sm:px-5">
          {error && <p role="alert" className="mb-2 text-xs text-ink">تعذّر تحديث القائمة: {error}</p>}
          <table className="w-full min-w-[620px] text-right text-sm">
            <thead className="border-y border-hairline bg-surface-2 text-xs text-ink-2">
              <tr>
                <th scope="col" className="px-3 py-2 font-medium">الحجز</th>
                <th scope="col" className="px-3 py-2 font-medium">الخدمة</th>
                <th scope="col" className="px-3 py-2 font-medium">الموعد</th>
                <th scope="col" className="px-3 py-2 font-medium">الحالة</th>
                <th scope="col" className="px-3 py-2 font-medium">الإجراء</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              {data.rows.map((booking) => (
                <tr key={booking.id}>
                  <td className="px-3 py-3">
                    <span dir="ltr" className="tnum font-semibold text-ink">{booking.reference}</span>
                    <span className="block text-xs text-muted">{booking.user_name}</span>
                  </td>
                  <td className="px-3 py-3 text-ink-2">{booking.service_title}</td>
                  <td className="px-3 py-3 whitespace-nowrap text-ink-2">{formatDate(booking.event_date)}</td>
                  <td className="px-3 py-3"><Badge tone={STATUS_TONE[booking.status]}>{BOOKING_STATUS_LABEL[booking.status]}</Badge></td>
                  <td className="px-3 py-3">
                    <Link to={`/bookings/${booking.id}`} className="font-medium text-accent underline underline-offset-4">
                      عرض
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}
