/**
 * ألوان التطبيق ومقاييسه.
 *
 * نُقلت من `src/index.css` في اللوحة ليبدو الطرفان منصةً واحدة: اللون الذهبي
 * نفسه، والرمادي نفسه. والألوان الدلالية (جيد/تحذير/خطر) هي التي فُحصت للتباين
 * هناك، فلا تُخترع هنا من جديد.
 */
export const colors = {
  page: '#faf8f4',
  surface: '#ffffff',
  surface2: '#f5f2ec',
  hairline: '#e7e1d6',
  ink: '#1c1a17',
  ink2: '#55504a',
  muted: '#8a8375',

  accent: '#9a6a00',
  accentInk: '#ffffff',

  good: '#2f7d52',
  warning: '#a9761a',
  critical: '#b3261e',
} as const

export const space = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  pill: 999,
} as const

export const text = {
  title: { fontSize: 20, fontWeight: '700' as const, color: colors.ink },
  heading: { fontSize: 16, fontWeight: '600' as const, color: colors.ink },
  body: { fontSize: 14, color: colors.ink2, lineHeight: 22 },
  small: { fontSize: 12, color: colors.muted },
  tiny: { fontSize: 11, color: colors.muted },
} as const
