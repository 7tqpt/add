import { Star } from 'lucide-react'

/**
 * Star row plus the numeric value.
 *
 * The number is not decoration: at small sizes a half-filled star is hard to
 * read, and it keeps the value available to anyone who cannot see the stars.
 */
export function Rating({ value, count }: { value: number; count?: number }) {
  if (value <= 0) return <span className="text-xs text-muted">لا يوجد تقييم</span>

  const rounded = Math.round(value)

  return (
    <span className="flex items-center gap-1.5 whitespace-nowrap">
      <span
        className="flex items-center gap-0.5"
        role="img"
        aria-label={`${value} من 5`}
      >
        {[1, 2, 3, 4, 5].map((step) => (
          <Star
            key={step}
            size={12}
            aria-hidden
            className={step <= rounded ? 'text-[var(--warning)]' : 'text-muted'}
            fill={step <= rounded ? 'var(--warning)' : 'none'}
          />
        ))}
      </span>
      <span className="tnum text-xs font-medium text-ink">{value.toFixed(1)}</span>
      {count !== undefined ? <span className="tnum text-xs text-muted">({count})</span> : null}
    </span>
  )
}
