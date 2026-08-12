import { useState, type KeyboardEvent as ReactKeyboardEvent, type PointerEvent as ReactPointerEvent } from 'react'
import { useElementWidth } from '@/hooks/useElementWidth'
import { formatDayMonth } from '@/lib/format'
import { CHART_PADDING, niceTicks, tickIndices, type SeriesDef, type TimePoint } from './chart-utils'

interface Props {
  points: TimePoint[]
  series: SeriesDef[]
  /** Height of the plot area; the x-axis band is added on top of it. */
  height?: number
  /** Subtle area under the line. Single-series charts only. */
  fill?: boolean
  formatValue: (value: number) => string
  formatTick?: (value: number) => string
}

const AXIS_BAND = CHART_PADDING.bottom

export function TimeSeriesChart({
  points,
  series,
  height = 210,
  fill = false,
  formatValue,
  formatTick = formatValue,
}: Props) {
  const { ref, width } = useElementWidth<HTMLDivElement>()
  const [active, setActive] = useState<number | null>(null)

  if (points.length < 2) {
    return (
      <div ref={ref} className="flex h-40 items-center justify-center text-xs text-muted">
        لا توجد بيانات كافية لرسم هذه الفترة.
      </div>
    )
  }

  const totalHeight = height + AXIS_BAND
  const plotLeft = CHART_PADDING.left
  const plotRight = Math.max(plotLeft + 1, width - CHART_PADDING.right)
  const plotTop = CHART_PADDING.top
  const plotBottom = height

  const maxValue = Math.max(...points.flatMap((point) => point.values), 0)
  const ticks = niceTicks(maxValue)
  const top = ticks[ticks.length - 1] || 1

  const lastIndex = points.length - 1
  // Time flows right → left to match the RTL reading direction: oldest on the
  // right edge, newest on the left.
  const xFor = (index: number) => plotRight - (index / lastIndex) * (plotRight - plotLeft)
  const yFor = (value: number) => plotBottom - (value / top) * (plotBottom - plotTop)

  const pathFor = (seriesIndex: number) =>
    points
      .map((point, i) => `${i === 0 ? 'M' : 'L'}${xFor(i).toFixed(1)},${yFor(point.values[seriesIndex] ?? 0).toFixed(1)}`)
      .join(' ')

  const areaFor = (seriesIndex: number) =>
    `${pathFor(seriesIndex)} L${xFor(lastIndex).toFixed(1)},${plotBottom} L${xFor(0).toFixed(1)},${plotBottom} Z`

  const xTicks = tickIndices(points.length, Math.max(2, Math.min(6, Math.floor(width / 90))))

  // Endpoint labels for the newest point; nudged apart when two series converge.
  const MIN_LABEL_GAP = 14
  const endpointLabels = series
    .map((entry, seriesIndex) => ({
      entry,
      y: yFor(points[lastIndex].values[seriesIndex] ?? 0),
      value: points[lastIndex].values[seriesIndex] ?? 0,
    }))
    .sort((a, b) => a.y - b.y)
    .reduce<{ entry: SeriesDef; y: number; value: number }[]>((placed, label) => {
      const previous = placed[placed.length - 1]
      const y =
        previous && label.y - previous.y < MIN_LABEL_GAP ? previous.y + MIN_LABEL_GAP : label.y
      placed.push({ ...label, y })
      return placed
    }, [])

  function handleMove(event: ReactPointerEvent<SVGSVGElement>) {
    const bounds = event.currentTarget.getBoundingClientRect()
    const x = event.clientX - bounds.left
    const ratio = (plotRight - x) / (plotRight - plotLeft)
    const index = Math.round(ratio * lastIndex)
    setActive(Math.min(lastIndex, Math.max(0, index)))
  }

  function handleKey(event: ReactKeyboardEvent<SVGSVGElement>) {
    if (event.key === 'Escape') return setActive(null)
    // In RTL the newer points sit to the left, so ArrowLeft steps forward in time.
    const step = event.key === 'ArrowLeft' ? 1 : event.key === 'ArrowRight' ? -1 : 0
    if (step === 0) return
    event.preventDefault()
    setActive((current) => {
      const next = (current ?? lastIndex) + step
      return Math.min(lastIndex, Math.max(0, next))
    })
  }

  const activePoint = active === null ? null : points[active]
  const tooltipX = active === null ? 0 : xFor(active)
  const tooltipSide = tooltipX > width / 2 ? 'end' : 'start'

  return (
    <div ref={ref} className="relative w-full">
      <svg
        width={width}
        height={totalHeight}
        viewBox={`0 0 ${width} ${totalHeight}`}
        style={{ direction: 'ltr' }}
        role="img"
        aria-label={`رسم بياني زمني: ${series.map((entry) => entry.label).join('، ')}`}
        tabIndex={0}
        onPointerMove={handleMove}
        onPointerLeave={() => setActive(null)}
        onBlur={() => setActive(null)}
        onKeyDown={handleKey}
        className="touch-none outline-none focus-visible:outline-2 focus-visible:outline-[var(--series-1)]"
      >
        <defs>
          <linearGradient id="area-fade" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={series[0]?.color} stopOpacity="0.22" />
            <stop offset="100%" stopColor={series[0]?.color} stopOpacity="0.02" />
          </linearGradient>
        </defs>

        {/* Solid hairline grid, one shade off the surface — never dashed. */}
        {ticks.map((tick) => (
          <g key={tick}>
            <line
              x1={plotLeft}
              x2={plotRight}
              y1={yFor(tick)}
              y2={yFor(tick)}
              stroke={tick === 0 ? 'var(--axis)' : 'var(--grid)'}
              strokeWidth="1"
            />
            <text
              x={plotRight + 8}
              y={yFor(tick) + 3.5}
              textAnchor="start"
              className="tnum"
              fill="var(--text-muted)"
              fontSize="10.5"
            >
              {formatTick(tick)}
            </text>
          </g>
        ))}

        {fill && series.length === 1 ? <path d={areaFor(0)} fill="url(#area-fade)" /> : null}

        {series.map((entry, seriesIndex) => (
          <path
            key={entry.label}
            d={pathFor(seriesIndex)}
            fill="none"
            stroke={entry.color}
            strokeWidth="2"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        ))}

        {/* Selective direct labels: the newest value only, never every point. */}
        {endpointLabels.map((label) => (
          <text
            key={label.entry.label}
            x={xFor(lastIndex) + 5}
            y={label.y - 9}
            textAnchor="start"
            className="tnum"
            fill="var(--text-secondary)"
            fontSize="10.5"
            fontWeight="600"
            // Surface-colored halo keeps the label readable where it crosses the line.
            stroke="var(--surface)"
            strokeWidth="3"
            paintOrder="stroke"
          >
            {formatValue(label.value)}
          </text>
        ))}

        {xTicks.map((index) => {
          const x = xFor(index)
          const anchor = x < 28 ? 'start' : x > plotRight - 12 ? 'end' : 'middle'
          return (
            <text
              key={index}
              x={x}
              y={totalHeight - 8}
              textAnchor={anchor}
              fill="var(--text-muted)"
              fontSize="10.5"
            >
              {formatDayMonth(points[index].date)}
            </text>
          )
        })}

        {active !== null ? (
          <g pointerEvents="none">
            <line
              x1={xFor(active)}
              x2={xFor(active)}
              y1={plotTop - 6}
              y2={plotBottom}
              stroke="var(--axis)"
              strokeWidth="1"
            />
            {series.map((entry, seriesIndex) => (
              <circle
                key={entry.label}
                cx={xFor(active)}
                cy={yFor(points[active].values[seriesIndex] ?? 0)}
                r="4.5"
                fill={entry.color}
                stroke="var(--surface)"
                strokeWidth="2"
              />
            ))}
          </g>
        ) : null}
      </svg>

      {activePoint ? (
        <div
          className="pointer-events-none absolute top-1 z-10 min-w-36 rounded-lg border border-hairline bg-surface px-3 py-2 text-xs shadow-lg"
          style={
            tooltipSide === 'end'
              ? { right: Math.max(4, width - tooltipX + 10) }
              : { left: Math.max(4, tooltipX + 10) }
          }
        >
          <p className="mb-1 font-medium text-ink">{formatDayMonth(activePoint.date)}</p>
          <ul className="flex flex-col gap-0.5">
            {series.map((entry, seriesIndex) => (
              <li key={entry.label} className="flex items-center justify-between gap-3">
                <span className="flex items-center gap-1.5 text-ink-2">
                  <span
                    aria-hidden
                    className="h-2 w-2 shrink-0 rounded-[2px]"
                    style={{ background: entry.color }}
                  />
                  {entry.label}
                </span>
                <span className="tnum font-medium text-ink">
                  {formatValue(activePoint.values[seriesIndex] ?? 0)}
                </span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  )
}
