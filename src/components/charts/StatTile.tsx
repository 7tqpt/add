import { ArrowDownRight, ArrowUpRight, Minus, type LucideIcon } from 'lucide-react'
import { formatDelta } from '@/lib/format'
import { cn } from '@/lib/cn'

/** ألوان تعريف البطاقات — مأخوذة من عالم العرس اليمني، لا من دولاب ألوان. */
export type Tone = 'gold' | 'henna' | 'indigo' | 'palm' | 'plum'

const TONE_VAR: Record<Tone, string> = {
  gold: 'var(--tile-gold)',
  henna: 'var(--tile-henna)',
  indigo: 'var(--tile-indigo)',
  palm: 'var(--tile-palm)',
  plum: 'var(--tile-plum)',
}

/**
 * ألوان البطاقة مشتقّة من صبغةٍ واحدة بـ`color-mix`، لا مكتوبة يدوياً.
 *
 * فائدتها أنها تُمزج مع سطح الثيمة الحالي: الوشاح نفسه يخرج فاتحاً على الأبيض
 * وداكناً على الأسود بلا جدولين، ويتغيّر مع الثيمة تلقائياً.
 */
export function toneStyle(tone: Tone) {
  const hue = TONE_VAR[tone]
  return {
    background: `color-mix(in oklab, ${hue} 11%, var(--surface))`,
    borderColor: `color-mix(in oklab, ${hue} 34%, var(--surface))`,
  } as const
}

/** شارةٌ هادئة للقوائم: خمسة مربّعات صريحة في عمودٍ واحد تصير ضجيجاً. */
export function toneChip(tone: Tone) {
  const hue = TONE_VAR[tone]
  return {
    background: `color-mix(in oklab, ${hue} 18%, var(--surface))`,
    color: hue,
  } as const
}

/** وشارةٌ صريحة للبطاقات الكبيرة، وهي أربع فتحتمل الصراحة. */
export function toneChipSolid(tone: Tone) {
  return { background: TONE_VAR[tone], color: 'var(--tile-ink)' } as const
}

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
  tone = 'gold',
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
  /** صبغة التعريف. لا تحمل حكماً على الرقم — ذلك عمل لون الفرق وحده. */
  tone?: Tone
  refetching?: boolean
}) {
  const direction = change === undefined ? null : change > 0.0005 ? 'up' : change < -0.0005 ? 'down' : 'flat'
  const DeltaIcon = direction === 'up' ? ArrowUpRight : direction === 'down' ? ArrowDownRight : Minus

  return (
    <section
      style={toneStyle(tone)}
      className={cn(
        'rounded-xl border p-4 shadow-[0_1px_2px_rgba(11,11,11,0.04)] sm:p-5',
        refetching && 'is-refetching',
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-medium text-ink-2">{label}</p>
        <span
          style={toneChipSolid(tone)}
          className="flex size-7 shrink-0 items-center justify-center rounded-lg"
        >
          <Icon size={15} aria-hidden />
        </span>
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
    </section>
  )
}
