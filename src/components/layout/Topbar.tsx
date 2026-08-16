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
 * رأس الصفحة، مصبوغٌ بصبغة القسم الذي أنت فيه.
 *
 * واللون هنا ليس زينة: اللوحة ستّ عشرة شاشةً متشابهة التخطيط، ومن ينتقل
 * بينها بسرعة يفقد إحساسه بموضعه. فصبغةٌ ثابتةٌ لكل قسم تُخبره أين هو قبل
 * أن يقرأ العنوان — وهي أسرع من القراءة بمراحل.
 *
 * والصبغة على القرص والخيط تحته فقط، لا على الرأس كلّه: رأسٌ ملوّنٌ بكامله
 * يصير جداراً يزاحم المحتوى، وخيطٌ رفيعٌ يكفي للدلالة.
 */
export function Topbar({ section, onOpenMenu }: { section: NavItem; onOpenMenu: () => void }) {
  const hue = TONE_VAR[section.tone]
  const Icon = section.icon

  return (
    <header
      className="sticky top-0 z-20 flex h-16 shrink-0 items-center justify-between gap-3 border-b border-hairline bg-surface/90 px-4 backdrop-blur sm:px-6"
      style={{
        // خيطٌ ملوّنٌ على الحافّة السفلى، ووهجٌ خفيفٌ ينزل منه.
        boxShadow: `inset 0 -2px 0 0 color-mix(in oklab, ${hue} 65%, transparent),
                    0 10px 24px -22px ${hue}`,
      }}
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

        <span
          aria-hidden
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl"
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

        <h1 className="truncate text-base font-semibold text-ink">{section.label}</h1>
      </div>

      <GlobalSearch />

      <div className="flex shrink-0 items-center gap-1.5">
        <UserMenu />
      </div>
    </header>
  )
}
