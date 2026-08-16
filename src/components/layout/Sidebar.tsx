import type { CSSProperties } from 'react'
import { NavLink } from 'react-router-dom'
import { X } from 'lucide-react'
import { cn } from '@/lib/cn'
import { useAuth } from '@/context/AuthContext'
import { BrandLockup } from '@/components/brand/Brand'

/** الصبغات نفسها التي يستعملها رأس الصفحة، فيتطابق القرصان لوناً. */
const TONE_VAR = {
  azure: 'var(--tile-azure)',
  emerald: 'var(--tile-emerald)',
  navy: 'var(--tile-navy)',
  cyan: 'var(--tile-cyan)',
  violet: 'var(--tile-violet)',
} as const
import { NAV_GROUPS } from './nav'

export function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { can } = useAuth()

  // مجموعةٌ خلت من بنودها لا تُعرض بعنوانها وحده.
  const groups = NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter((item) => can(item.area, 'read')),
  })).filter((group) => group.items.length > 0)

  return (
    <>
      {/* Scrim, mobile only — the sidebar is always visible from lg up. */}
      <div
        className={cn(
          'fixed inset-0 z-30 bg-black/40 transition-opacity lg:hidden',
          open ? 'opacity-100' : 'pointer-events-none opacity-0',
        )}
        onClick={onClose}
        aria-hidden
      />

      <aside
        className={cn(
          // start-0 is the right edge under dir="rtl"; the border sits on the
          // inline-end side, facing the content.
          'fixed inset-y-0 start-0 z-40 flex w-64 flex-col border-e border-hairline bg-surface transition-transform lg:static lg:translate-x-0',
          // Transforms are not direction-aware: +100% X parks it off the right edge.
          open ? 'translate-x-0' : 'translate-x-full lg:translate-x-0',
        )}
      >
        <div className="flex h-16 shrink-0 items-center justify-between gap-2 border-b border-hairline px-4">
          <BrandLockup size={36} />
          <button
            type="button"
            onClick={onClose}
            className="cursor-pointer rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-ink lg:hidden"
            aria-label="إغلاق القائمة"
          >
            <X size={18} aria-hidden />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3">
          {groups.map((group, index) => (
            <div key={group.label ?? 'main'} className={index === 0 ? '' : 'mt-4'}>
              {group.label ? (
                <p className="px-3 pb-1.5 text-[11px] font-medium tracking-wide text-muted">
                  {group.label}
                </p>
              ) : null}
              <ul className="flex flex-col gap-1">
                {group.items.map((item) => (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      end={item.to === '/'}
                      onClick={onClose}
                      // الصبغة على البند نفسه لا على قرصه: الحبّة والقرص
                      // كلاهما يقرأها، فلا تُكتب مرّتين ولا تفترقان لوناً.
                      style={{ '--tone': TONE_VAR[item.tone] } as CSSProperties}
                      className={({ isActive }) =>
                        cn(
                          'nav-item nav-pill relative flex h-10 items-center gap-2.5 overflow-hidden rounded-xl px-2.5 text-sm font-medium transition-colors',
                          // شريطٌ على الحافّة الداخلية للبند النشط: علامةٌ
                          // ثانية غير اللون، فمن لا يفرّق الألوان يرى موضعه.
                          isActive
                            ? 'nav-pill-active text-ink before:absolute before:inset-y-1.5 before:start-0 before:w-[3px] before:rounded-full before:bg-[var(--tone)]'
                            : 'text-ink-2 hover:text-ink',
                        )
                      }
                    >
                      {({ isActive }) => (
                        <>
                          {/* الأيقونة في قرصٍ زجاجيّ: القرص يعطيها جسماً
                              ويجعل صفَّ البنود مقروءاً بمسحةٍ واحدة، بدل
                              رموزٍ عائمةٍ في الفراغ تتفاوت أوزانها. */}
                          <span
                            className={cn(
                              'icon-glass',
                              isActive && 'icon-glass-active',
                            )}
                          >
                            <item.icon
                              size={16}
                              aria-hidden
                              style={{ color: isActive ? TONE_VAR[item.tone] : undefined }}
                              className={isActive ? undefined : 'text-ink-2'}
                            />
                          </span>
                          {item.label}
                        </>
                      )}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>

        <p className="border-t border-hairline px-4 py-3 text-[11px] text-muted">الإصدار 0.1.0</p>
      </aside>
    </>
  )
}
