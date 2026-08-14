import { NavLink } from 'react-router-dom'
import { PartyPopper, X } from 'lucide-react'
import { cn } from '@/lib/cn'
import { useAuth } from '@/context/AuthContext'
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
          <div className="flex items-center gap-2.5">
            <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-ink">
              <PartyPopper size={18} aria-hidden />
            </span>
            <div className="leading-tight">
              <p className="text-sm font-semibold text-ink">لوحة التحكم</p>
              <p className="text-[11px] text-muted">منصة حجوزات الأعراس</p>
            </div>
          </div>
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
                      className={({ isActive }) =>
                        cn(
                          'flex h-10 items-center gap-2.5 rounded-lg px-3 text-sm font-medium transition-colors',
                          isActive
                            ? 'bg-surface-2 text-ink'
                            : 'text-ink-2 hover:bg-surface-2 hover:text-ink',
                        )
                      }
                    >
                      {({ isActive }) => (
                        <>
                          <item.icon
                            size={17}
                            aria-hidden
                            className={isActive ? 'text-accent' : 'text-muted'}
                          />
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
