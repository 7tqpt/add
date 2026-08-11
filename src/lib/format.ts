/**
 * Arabic locale with Latin digits and the Gregorian calendar: Arabic separators
 * and month names, but numerals that stay legible next to version strings and
 * chart axes.
 */
const LOCALE = 'ar-EG-u-nu-latn-ca-gregory'

const int = new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 0 })
const oneDecimal = new Intl.NumberFormat(LOCALE, {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
})
const percent = new Intl.NumberFormat(LOCALE, {
  style: 'percent',
  maximumFractionDigits: 1,
})
const dayMonth = new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'short' })
const fullDate = new Intl.DateTimeFormat(LOCALE, {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
})
const dateTime = new Intl.DateTimeFormat(LOCALE, {
  day: 'numeric',
  month: 'short',
  hour: 'numeric',
  minute: '2-digit',
})

export const formatNumber = (n: number) => int.format(n)

/** 12_400 → "12.4 ألف". Used on axis ticks and tight stat tiles. */
export function formatCompact(n: number): string {
  const abs = Math.abs(n)
  if (abs >= 1_000_000) return `${oneDecimal.format(n / 1_000_000)} م`
  if (abs >= 10_000) return `${int.format(Math.round(n / 1000))} ألف`
  if (abs >= 1000) return `${oneDecimal.format(n / 1000)} ألف`
  return int.format(n)
}

export const formatPercent = (fraction: number) => percent.format(fraction)

/**
 * The currency suffix is appended manually rather than via `style: 'currency'`:
 * the CLDR symbol for SAR ends in a period, which bidi reordering strands at the
 * far edge of the number ("‎.145,873 ر.س").
 */
export const formatMoney = (n: number) => `${int.format(n)} ر.س`

/** Signed percentage for delta cues: "+12.4%" / "−3.1%". */
export function formatDelta(fraction: number): string {
  const sign = fraction > 0 ? '+' : fraction < 0 ? '−' : ''
  return `${sign}${percent.format(Math.abs(fraction))}`
}

export const formatDayMonth = (iso: string) => dayMonth.format(new Date(iso))

export const formatDate = (iso: string) => fullDate.format(new Date(iso))

export const formatDateTime = (iso: string) => dateTime.format(new Date(iso))

/** "منذ 3 ساعات". Falls back to an absolute date past a month. */
export function formatRelative(iso: string | null): string {
  if (!iso) return '—'
  const diffMs = Date.now() - new Date(iso).getTime()
  const minutes = Math.round(diffMs / 60_000)
  if (minutes < 1) return 'الآن'
  if (minutes < 60) return `منذ ${int.format(minutes)} دقيقة`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `منذ ${int.format(hours)} ساعة`
  const days = Math.round(hours / 24)
  if (days < 30) return `منذ ${int.format(days)} يوم`
  return fullDate.format(new Date(iso))
}

/** 3_720 → "1 س 2 د". Session lengths, never wall-clock times. */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '—'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  // A whole number of hours reads as "4 س", not "4 س 0 د".
  if (hours > 0) return minutes === 0 ? `${int.format(hours)} س` : `${int.format(hours)} س ${int.format(minutes)} د`
  if (minutes > 0) return `${int.format(minutes)} د`
  return `${int.format(Math.round(seconds))} ث`
}

export const PLATFORM_LABEL: Record<string, string> = {
  ios: 'iOS',
  android: 'Android',
}
