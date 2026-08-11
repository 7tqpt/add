/** Categorical slots, in the fixed validated order. Never cycled, never re-ranked. */
export const SERIES_COLORS = ['var(--series-1)', 'var(--series-2)', 'var(--series-3)'] as const

export interface SeriesDef {
  label: string
  color: string
}

/** One x position with a value per series. */
export interface TimePoint {
  date: string
  values: number[]
}

/**
 * Axis ticks on 1/2/5×10ⁿ steps, so labels land on numbers a reader recognises
 * (200, 400, 600) rather than on the data's raw extent.
 */
export function niceTicks(max: number, count = 4): number[] {
  if (!Number.isFinite(max) || max <= 0) return [0, 1]
  const rawStep = max / count
  const magnitude = 10 ** Math.floor(Math.log10(rawStep))
  const normalized = rawStep / magnitude
  const step = (normalized > 5 ? 10 : normalized > 2 ? 5 : normalized > 1 ? 2 : 1) * magnitude
  const top = Math.ceil(max / step) * step
  const ticks: number[] = []
  for (let value = 0; value <= top + step / 2; value += step) ticks.push(value)
  return ticks
}

/** Evenly spaced label indices, always including the first and last point. */
export function tickIndices(length: number, desired: number): number[] {
  if (length <= desired) return Array.from({ length }, (_, i) => i)
  const step = (length - 1) / (desired - 1)
  const indices = Array.from({ length: desired }, (_, i) => Math.round(i * step))
  return [...new Set(indices)]
}

export const CHART_PADDING = {
  top: 14,
  right: 52,
  bottom: 26,
  left: 14,
} as const
