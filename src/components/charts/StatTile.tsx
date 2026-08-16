import type { CSSProperties } from 'react'
import { ArrowDownRight, ArrowUpRight, Minus, type LucideIcon } from 'lucide-react'
import { formatDelta } from '@/lib/format'
import { cn } from '@/lib/cn'

/**
 * أصباغ تعريف البطاقات — والإسناد قاعدةٌ واحدة عبر اللوحة كلها، لا اختيارٌ
 * في كل صفحة:
 *
 *   emerald  المال الداخل — المحصّل، الأرباح، المدفوعات
 *   navy     العمولة وحصّة المنصة، وما يُعدّ من نشاطٍ إداري
 *   cyan     الصحّة والنشاط — نِسب النجاح، المستخدمون، الأزمنة
 *   azure    العدّ الأساسي لما تبيعه المنصة — الحجوزات والتذاكر
 *   violet   ما خرج عن الأربعة — الاسترجاع مثلاً
 *
 * فمن رأى الأخضر في «المدفوعات» عرفه في «مقدّم الخدمة» بلا أن يقرأ.
 *
 * وهي باردةٌ كلها تدور حول الأزرق إلا `emerald`: خمس درجاتٍ من أزرقٍ واحد
 * لا تُفرَّق، والمال يستحقّ أن يُميَّز عمّا سواه.
 */
export type Tone = 'azure' | 'emerald' | 'navy' | 'cyan' | 'violet'

const TONE_VAR: Record<Tone, string> = {
  azure: 'var(--tile-azure)',
  emerald: 'var(--tile-emerald)',
  navy: 'var(--tile-navy)',
  cyan: 'var(--tile-cyan)',
  violet: 'var(--tile-violet)',
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
    // الصبغة تُمزج بالسطح أوّلاً ثم يُخفَّف الناتج بالشفافية: مزجُ الصبغة
    // بالشفّاف مباشرةً يُذهب لونها مع كثافتها معاً، والمطلوب أن يبقى اللون
    // ويخفّ الحجاب وحده.
    background: `color-mix(in oklab, color-mix(in oklab, ${hue} 13%, var(--surface)) 78%, transparent)`,
    // الحدّ في متغيّرٍ لا في `borderColor` مباشرةً: النمط المضمّن يسبق كل صنف،
    // فحدٌّ مكتوبٌ هنا لا تستطيع حالةُ `:active` أن تغيّره — وتبقى قاعدة
    // الضغط مكتوبةً وهي لا تفعل شيئاً، وذلك أسوأ من غيابها.
    '--tile-border': `color-mix(in oklab, ${hue} 34%, var(--surface))`,
  } as CSSProperties
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
  tone = 'azure',
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
        'glass-tile rounded-xl border p-4 sm:p-5',
        // بلا `rise` هنا: البطاقات تقع داخل شبكةٍ تحمل `stagger`، وهي التي
        // تُدخلها متتابعةً. ولو حملت الاثنين لتضاربت الحركتان على العنصر نفسه.
        'lift press-card',
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
        className="mt-2 text-2xl font-semibold tracking-tight text-ink sm:text-[1.6rem]"
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
