import { NavLink } from 'react-router-dom'
import { X } from 'lucide-react'
import { cn } from '@/lib/cn'
import { useAuth } from '@/context/AuthContext'
import { BrandLockup } from '@/components/brand/Brand'

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

      {/*
        ── (أ) «المخمل» — اختارها صاحبُ المنصّة من ثلاثة اتجاهات ──────────
        قائمةٌ نبيذيّةٌ في الوضعين، في رأسها مخملُ الورد من شاشة ترحيب
        التطبيق، والبندُ النشطُ ورقةٌ كريميّةٌ بحافّةٍ ذهبيّة. **وبلا أقراصٍ
        حول الأيقونات**: كانت زجاجاً مصبوغاً بصبغة القسم، وعلى النبيذيّ تُقرأ
        بقعاً — والصورةُ أيقوناتٌ خطّيّةٌ وحدها.
      */}
      <aside
        data-sidebar
        style={{ background: 'linear-gradient(180deg, var(--side-from), var(--side-to) 62%, var(--side-from))' }}
        className={cn(
          // start-0 is the right edge under dir="rtl".
          'fixed inset-y-0 start-0 z-40 flex w-64 flex-col text-[var(--side-ink)] transition-transform lg:static lg:translate-x-0',
          // Transforms are not direction-aware: +100% X parks it off the right edge.
          open ? 'translate-x-0' : 'translate-x-full lg:translate-x-0',
        )}
      >
        <div
          data-sidebar-head
          className="relative flex h-28 shrink-0 items-end justify-between gap-2 overflow-hidden px-4 pb-3"
          style={{ background: 'url(/brand/roses.webp) center 30% / cover' }}
        >
          {/* يُعتَم الوردُ من تحت ليُقرأ الاسمُ عليه — ويذوب في نبيذيّ القائمة. */}
          <span
            aria-hidden
            className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, rgba(92,8,32,0.1), rgba(92,8,32,0.88))' }}
          />
          <span className="relative">
            <BrandLockup size={40} tone="invert" />
          </span>
          <button
            type="button"
            onClick={onClose}
            className="relative cursor-pointer rounded-md p-1.5 text-white/80 hover:bg-white/10 hover:text-white lg:hidden"
            aria-label="إغلاق القائمة"
          >
            <X size={18} aria-hidden />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 pb-3 pt-2">
          {groups.map((group, index) => (
            <div key={group.label ?? 'main'} className={index === 0 ? '' : 'mt-3'}>
              {group.label ? (
                <p className="px-3 pb-1 text-[11px] font-medium tracking-wide text-[var(--side-gold)] opacity-80">
                  {group.label}
                </p>
              ) : null}
              <ul className="flex flex-col gap-0.5">
                {group.items.map((item) => (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      end={item.to === '/'}
                      onClick={onClose}
                      className={({ isActive }) =>
                        cn(
                          'nav-item relative flex h-10 items-center gap-2.5 rounded-xl px-3 text-sm transition-colors',
                          // **وعلامةٌ ثانيةٌ غير اللون** للبند النشط: حافّةٌ
                          // ذهبيّةٌ على طرفه — فمن لا يفرّق الألوان يرى موضعه.
                          isActive
                            ? 'bg-[#f7e9ec] font-bold text-[#7b0f2e] shadow-[inset_3px_0_0_var(--side-gold)]'
                            : 'font-medium text-[var(--side-muted)] hover:bg-white/8 hover:text-[var(--side-ink)]',
                        )
                      }
                    >
                      <item.icon size={18} aria-hidden strokeWidth={1.8} />
                      {item.label}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>

        {/* صانعةُ اللوحة — كانت علامتَها، فبقي اسمُها هنا. */}
        <p className="border-t border-white/10 px-4 py-3 text-[11px] text-[var(--side-muted)]">
          من سد للبرمجيات
        </p>
      </aside>
    </>
  )
}
