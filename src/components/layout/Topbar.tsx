import type { CSSProperties } from 'react'
import { Menu } from 'lucide-react'
import { GlobalSearch } from './GlobalSearch'
import { UserMenu } from './UserMenu'
import type { NavItem } from './nav'

const TONE_VAR = {
  azure: 'var(--tile-azure)',
  emerald: 'var(--tile-emerald)',
  navy: 'var(--tile-navy)',
  cyan: 'var(--tile-cyan)',
  violet: 'var(--tile-violet)',
} as const

/**
 * رأس الصفحة: زجاجٌ مصبوغٌ بصبغة القسم، وقرصٌ ينقلب عند تبدّله.
 *
 * واللون هنا ليس زينة: اللوحة ستّ عشرة شاشةً متشابهة التخطيط، ومن ينتقل
 * بينها بسرعة يفقد إحساسه بموضعه. فصبغةٌ ثابتةٌ لكل قسم تُخبره أين هو قبل
 * أن يقرأ العنوان — وهي أسرع من القراءة بمراحل. والانقلابة تُعلن التبدّل
 * نفسه، فمن ضغط بنداً يرى أن شيئاً استجاب لضغطته.
 *
 * وزجاج هذا الشريط وحده صادق: هو لاصقٌ فوق مساحةٍ تُمرَّر تحته، فيجد الضبابُ
 * محتوىً حقيقياً يضبّبه. أمّا الزجاج في البطاقات والقائمة فمبنيٌّ من تدرّجٍ
 * وحدٍّ وخطِّ ضوء، لأن ما خلفها سطحٌ مصمت.
 */
export function Topbar({ section, onOpenMenu }: { section: NavItem; onOpenMenu: () => void }) {
  const hue = TONE_VAR[section.tone]
  const Icon = section.icon

  return (
    <header
      className="topbar-glass scene-sm sticky top-0 z-20 flex h-16 shrink-0 items-center justify-between gap-3 border-b border-hairline px-4 sm:px-6"
      style={{ '--tone': hue } as CSSProperties}
    >
      <div className="flex min-w-0 items-center gap-2">
        <button
          type="button"
          onClick={onOpenMenu}
          className="icon-press cursor-pointer rounded-md p-2 text-ink-2 hover:bg-surface-2 lg:hidden"
          aria-label="فتح القائمة"
        >
          <Menu size={18} aria-hidden />
        </button>

        {/*
          `key` هو ما يُعيد تشغيل الانقلابة: العنصر يُستبدل عند كل قسم فتبدأ
          الحركة من أوّلها. ولو بقي العنصر نفسه وتغيّر لونه وحده لما تحرّك
          شيء — وهو الفخّ الذي يقع فيه من يكتفي بتبديل الأنماط.
        */}
        <span
          key={section.to}
          aria-hidden
          className="chip-3d tilt-hover flex h-9 w-9 shrink-0 items-center justify-center rounded-xl"
          style={{
            background: `color-mix(in oklab, ${hue} 16%, transparent)`,
            border: `1px solid color-mix(in oklab, ${hue} 34%, transparent)`,
            boxShadow: `inset 0 1px 0 color-mix(in oklab, white 45%, transparent),
                        0 6px 16px -10px ${hue}`,
            color: hue,
          }}
        >
          <Icon size={17} />
        </span>

        <h1 key={`${section.to}-title`} className="title-in truncate text-base font-semibold text-ink">
          {section.label}
        </h1>
      </div>

      <GlobalSearch />

      <div className="flex shrink-0 items-center gap-1.5">
        <UserMenu />
      </div>
    </header>
  )
}
