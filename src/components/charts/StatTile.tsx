import { ArrowDownRight, ArrowUpRight, Minus, type LucideIcon } from 'lucide-react'
import { Card } from '@/components/ui/Card'
import { formatDelta } from '@/lib/format'
import { cn } from '@/lib/cn'

/**
 * A single headline number. When the story is one figure, this is the chart —
 * a one-bar bar chart would say the same thing with more ink.
 */
export function StatTile({
  label,
  value,
  valueTitle,
  change,
  comparisonLabel,
  icon: Icon,
  refetching,
}: {
  label: string
  value: string
  /** The exact figure, when `value` is abbreviated to fit the tile. */
  valueTitle?: string
  /** Fractional change vs. the previous period; omit when there is nothing to compare. */
  change?: number
  comparisonLabel?: string
  icon: LucideIcon
  refetching?: boolean
}) {
  const direction = change === undefined ? null : change > 0.0005 ? 'up' : change < -0.0005 ? 'down' : 'flat'
  const DeltaIcon = direction === 'up' ? ArrowUpRight : direction === 'down' ? ArrowDownRight : Minus

  return (
    <Card className={cn('p-4 sm:p-5', refetching && 'is-refetching')}>
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-medium text-ink-2">{label}</p>
        <Icon size={16} className="shrink-0 text-muted" aria-hidden />
      </div>

      {/* Proportional figures: tabular-nums makes large standalone numbers look loose. */}
      <p
        title={valueTitle}
        className="mt-2 text-2xl font-semibold tracking-tight text-ink sm:text-3xl"
      >
        {value}
      </p>

      {direction ? (
        <p className="mt-2 flex items-center gap-1.5 text-xs">
          <span
            className="inline-flex items-center gap-0.5 font-medium"
            style={{
              color:
                direction === 'up'
                  ? 'var(--delta-up)'
                  : direction === 'down'
                    ? 'var(--delta-down)'
                    : 'var(--text-muted)',
            }}
          >
            {/* Icon + sign carry the direction; the color only reinforces it. */}
            <DeltaIcon size={13} aria-hidden />
            {formatDelta(change ?? 0)}
          </span>
          {comparisonLabel ? <span className="text-muted">{comparisonLabel}</span> : null}
        </p>
      ) : null}
    </Card>
  )
}
