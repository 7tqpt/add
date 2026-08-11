import { formatNumber, formatPercent } from '@/lib/format'

export interface ShareSegment {
  label: string
  value: number
  color: string
}

/**
 * Part-to-whole across a handful of segments — the honest form for a two-way
 * split, where a pie would be two slices and a bar chart would lose the "whole".
 */
export function ShareBar({ segments }: { segments: ShareSegment[] }) {
  const total = segments.reduce((acc, segment) => acc + segment.value, 0)
  if (total === 0) {
    return <p className="py-6 text-center text-xs text-muted">لا توجد بيانات.</p>
  }

  return (
    <div className="flex flex-col gap-3">
      {/* gap-0.5 = the 2px surface gap that separates fills without a border. */}
      <div className="flex h-7 w-full gap-0.5 overflow-hidden rounded-[4px]">
        {segments.map((segment) => (
          <div
            key={segment.label}
            className="h-full first:rounded-s-[4px] last:rounded-e-[4px]"
            style={{ width: `${(segment.value / total) * 100}%`, background: segment.color }}
            title={`${segment.label}: ${formatPercent(segment.value / total)}`}
          />
        ))}
      </div>

      <ul className="flex flex-col gap-1.5">
        {segments.map((segment) => (
          <li key={segment.label} className="flex items-center justify-between gap-3 text-xs">
            <span className="flex items-center gap-2 text-ink-2">
              <span
                aria-hidden
                className="h-2.5 w-2.5 shrink-0 rounded-[2px]"
                style={{ background: segment.color }}
              />
              {segment.label}
            </span>
            <span className="tnum text-ink">
              <span className="font-medium">{formatPercent(segment.value / total)}</span>
              <span className="text-muted"> · {formatNumber(segment.value)}</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
