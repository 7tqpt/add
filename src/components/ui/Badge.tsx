import { AlertTriangle, CheckCircle2, Clock, XCircle, type LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'

/** A status is never carried by color alone — every tone ships with an icon. */
export type Tone = 'good' | 'warning' | 'serious' | 'critical' | 'neutral'

const TONE_CLASS: Record<Tone, string> = {
  good: 'text-[var(--good)] border-[color-mix(in_oklab,var(--good)_35%,transparent)] bg-[color-mix(in_oklab,var(--good)_10%,transparent)]',
  warning:
    'text-[var(--text-primary)] border-[color-mix(in_oklab,var(--warning)_45%,transparent)] bg-[color-mix(in_oklab,var(--warning)_16%,transparent)]',
  serious:
    'text-[var(--text-primary)] border-[color-mix(in_oklab,var(--serious)_45%,transparent)] bg-[color-mix(in_oklab,var(--serious)_16%,transparent)]',
  critical:
    'text-[var(--critical)] border-[color-mix(in_oklab,var(--critical)_35%,transparent)] bg-[color-mix(in_oklab,var(--critical)_10%,transparent)]',
  neutral: 'text-ink-2 border-hairline bg-surface-2',
}

const TONE_ICON: Record<Tone, LucideIcon> = {
  good: CheckCircle2,
  warning: Clock,
  serious: AlertTriangle,
  critical: XCircle,
  neutral: Clock,
}

export function Badge({
  tone = 'neutral',
  icon = true,
  children,
}: {
  tone?: Tone
  /**
   * `false` drops the icon; a component overrides the tone's default one, for
   * states the tone alone would mislabel — a rejected item is neutral in
   * severity but a clock would read as "still waiting".
   */
  icon?: boolean | LucideIcon
  children: ReactNode
}) {
  const Icon = typeof icon === 'function' ? icon : TONE_ICON[tone]
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-xs font-medium whitespace-nowrap',
        TONE_CLASS[tone],
      )}
    >
      {icon !== false ? <Icon size={13} aria-hidden className="shrink-0" /> : null}
      {children}
    </span>
  )
}
