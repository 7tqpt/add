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
            className="group relative flex min-h-6 items-center gap-3"
            onPointerEnter={() => setHovered(datum.label)}
            onPointerLeave={() => setHovered(null)}
            onFocus={() => setHovered(datum.label)}
            onBlur={() => setHovered(null)}
            tabIndex={0}
          >
            <span className="w-28 shrink-0 truncate text-xs text-ink-2" title={datum.label}>
              {datum.label}
            </span>
            {/* (أ): عمودٌ نحيفٌ مدوَّرٌ بتدرّجٍ من لونه على مجرىً ذهبيٍّ فاتح. والهدفُ
                للمؤشّر واللمس هو الصفُّ كلُّه (`min-h-6`) لا العمودُ النحيف. */}
            <span data-bar-track className="relative flex h-3 flex-1 items-center rounded-full bg-gold-soft">
              <span
                data-bar
                className="h-3 rounded-full transition-[width] duration-300"
                style={{
                  width: `${(datum.value / max) * 100}%`,
                  background: `linear-gradient(90deg, color-mix(in oklab, ${color} 72%, black), color-mix(in oklab, ${color} 88%, white))`,
                }}
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
                'pointer-events-none absolute -top-8 start-32 z-10 rounded-lg border border-hairline bg-surface px-2.5 py-1 text-xs whitespace-nowrap text-ink shadow-lg transition-opacity',
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
