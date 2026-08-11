import { useState } from 'react'
import { cn } from '@/lib/cn'

export interface BarDatum {
  label: string
  value: number
}

/**
 * Horizontal bars for a nominal category (countries, versions).
 *
 * One series, one color — the bar length already encodes magnitude, so shading
 * each bar by its own value would spend the color channel on nothing.
 */
export function BarChart({
  data,
  formatValue,
  color = 'var(--series-1)',
}: {
  data: BarDatum[]
  formatValue: (value: number) => string
  color?: string
}) {
  const [hovered, setHovered] = useState<string | null>(null)
  const max = Math.max(...data.map((datum) => datum.value), 1)
  const total = data.reduce((acc, datum) => acc + datum.value, 0)

  if (data.length === 0) {
    return <p className="py-10 text-center text-xs text-muted">لا توجد بيانات.</p>
  }

  return (
    <ul className="flex flex-col gap-2.5">
      {data.map((datum) => {
        const share = total > 0 ? datum.value / total : 0
        return (
          <li
            key={datum.label}
            className="group relative flex items-center gap-3"
            onPointerEnter={() => setHovered(datum.label)}
            onPointerLeave={() => setHovered(null)}
            onFocus={() => setHovered(datum.label)}
            onBlur={() => setHovered(null)}
            tabIndex={0}
          >
            <span className="w-20 shrink-0 truncate text-xs text-ink-2" title={datum.label}>
              {datum.label}
            </span>
            {/* Track height 24px keeps the hover/focus target above the minimum. */}
            <span className="relative flex h-6 flex-1 items-center rounded-[4px] bg-surface-2">
              <span
                className="h-6 rounded-[4px] transition-[width] duration-300"
                style={{ width: `${(datum.value / max) * 100}%`, background: color }}
              />
            </span>
            {/* Auto width, never wrapped: a fixed column breaks currency labels
                like "5,048 ر.س" across two lines. */}
            <span className="tnum shrink-0 text-start text-xs font-medium whitespace-nowrap text-ink">
              {formatValue(datum.value)}
            </span>

            <span
              role="status"
              className={cn(
                'pointer-events-none absolute -top-8 start-24 z-10 rounded-lg border border-hairline bg-surface px-2.5 py-1 text-xs whitespace-nowrap text-ink shadow-lg transition-opacity',
                hovered === datum.label ? 'opacity-100' : 'opacity-0',
              )}
            >
              {datum.label}: {formatValue(datum.value)} ({Math.round(share * 100)}%)
            </span>
          </li>
        )
      })}
    </ul>
  )
}
