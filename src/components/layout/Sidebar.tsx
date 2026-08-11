import { NavLink } from 'react-router-dom'
import { Smartphone, X } from 'lucide-react'
import { cn } from '@/lib/cn'
import { NAV_ITEMS } from './nav'

export function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
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
            <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-series-1 text-white">
              <Smartphone size={18} aria-hidden />
            </span>
            <div className="leading-tight">
              <p className="text-sm font-semibold text-ink">لوحة التحكم</p>
              <p className="text-[11px] text-muted">إدارة تطبيق الجوال</p>
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
          <ul className="flex flex-col gap-1">
            {NAV_ITEMS.map((item) => (
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
                        className={isActive ? 'text-series-1' : 'text-muted'}
                      />
                      {item.label}
                    </>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        <p className="border-t border-hairline px-4 py-3 text-[11px] text-muted">الإصدار 0.1.0</p>
      </aside>
    </>
  )
}
