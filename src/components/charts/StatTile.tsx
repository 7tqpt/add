import { ArrowDownRight, ArrowUpRight, Minus, type LucideIcon } from 'lucide-react'
import { formatDelta } from '@/lib/format'
import { cn } from '@/lib/cn'

/**
 * أصباغُ التعريف — لشاراتِ القوائم وأقسام التنقّل (`toneChip`)، لا لبطاقات
 * الأرقام: تلك صارت شكلاً واحداً في (أ). والإسنادُ قاعدةٌ واحدة:
 *
 *   emerald  المال الداخل — المحصّل، الأرباح، المدفوعات
 *   navy     العمولة وحصّة المنصة، وما يُعدّ من نشاطٍ إداري
 *   cyan     الصحّة والنشاط — نِسب النجاح، المستخدمون، الأزمنة
 *   azure    العدّ الأساسي لما تبيعه المنصة — الحجوزات والتذاكر
 *   violet   ما خرج عن الأربعة — الاسترجاع مثلاً
 *
 * والأسماءُ باقيةٌ من العهد الأزرق، وألوانُها عائلةُ العلامة (`--tile-*`).
 */
export type Tone = 'azure' | 'emerald' | 'navy' | 'cyan' | 'violet'

const TONE_VAR: Record<Tone, string> = {
  azure: 'var(--tile-azure)',
  emerald: 'var(--tile-emerald)',
  navy: 'var(--tile-navy)',
  cyan: 'var(--tile-cyan)',
  violet: 'var(--tile-violet)',
}

/** شارةٌ هادئة للقوائم: خمسة مربّعات صريحة في عمودٍ واحد تصير ضجيجاً. */
export function toneChip(tone: Tone) {
  const hue = TONE_VAR[tone]
  return {
    background: `color-mix(in oklab, ${hue} 18%, var(--surface))`,
    color: hue,
  } as const
}

/**
 * A single headline number. When the story is one figure, this is the chart —
 * a one-bar bar chart would say the same thing with more ink.
 *
 * (أ) اختارها صاحبُ المنصّة من صورتين: بطاقةٌ بيضاءُ بقرصٍ ذهبيّ ورقمٍ نبيذيّ،
 * كبطاقات «نظرة عامة» تماماً — لا مصبوغةٌ بصبغة نوعها. فالبطاقاتُ في اللوحة
 * كلّها شكلٌ واحد، والنوعُ يُقرأ من العنوان والأيقونة.
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
    <section
      data-stat
      className={cn(
        'rounded-2xl border border-hairline bg-surface p-4 sm:p-5',
        // بلا `rise` هنا: البطاقات تقع داخل شبكةٍ تحمل `stagger`، وهي التي
        // تُدخلها متتابعةً. ولو حملت الاثنين لتضاربت الحركتان على العنصر نفسه.
        'lift press-card',
        refetching && 'is-refetching',
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-medium text-ink-2">{label}</p>
        <span
          data-stat-disc
          className="flex size-11 shrink-0 items-center justify-center rounded-full bg-gold-soft text-gold-ink"
        >
          <Icon size={20} aria-hidden strokeWidth={1.8} />
        </span>
      </div>

      {/* Proportional figures: tabular-nums makes large standalone numbers look loose. */}
      <p
        title={valueTitle}
        className="mt-1 text-2xl font-bold tracking-tight text-accent sm:text-[1.6rem]"
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
