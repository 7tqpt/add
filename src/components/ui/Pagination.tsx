import { ChevronLeft, ChevronRight } from 'lucide-react'
import { formatNumber } from '@/lib/format'
import { Button } from './Button'

/**
 * Shared pager for every server-paginated list.
 *
 * The chevrons are mirrored on purpose: under `dir="rtl"` "previous" points
 * toward the start edge, which is the right.
 */
export function Pagination({
  page,
  pageSize,
  total,
  onChange,
}: {
  page: number
  pageSize: number
  total: number
  onChange: (page: number) => void
}) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize))
  const rangeStart = total === 0 ? 0 : page * pageSize + 1
  const rangeEnd = Math.min(total, (page + 1) * pageSize)

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-hairline px-4 py-3">
      <p className="tnum text-xs text-muted">
        عرض {formatNumber(rangeStart)}–{formatNumber(rangeEnd)} من {formatNumber(total)}
      </p>
      <div className="flex items-center gap-2">
        <Button size="sm" disabled={page === 0} onClick={() => onChange(Math.max(0, page - 1))}>
          <ChevronRight size={14} aria-hidden />
          السابق
        </Button>
        <span className="tnum text-xs text-ink-2">
          {formatNumber(page + 1)} / {formatNumber(pageCount)}
        </span>
        <Button
          size="sm"
          disabled={page + 1 >= pageCount}
          onClick={() => onChange(page + 1)}
        >
          التالي
          <ChevronLeft size={14} aria-hidden />
        </Button>
      </div>
    </div>
  )
}
