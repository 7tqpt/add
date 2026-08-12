import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { Database } from 'lucide-react'
import { cn } from '@/lib/cn'
import { useAuth } from '@/context/AuthContext'
import { ROLES_IN_ORDER, ROLE_LABEL } from '@/lib/permissions'
import { isSupabaseConfigured } from '@/lib/supabase'
import type { AdminRole } from '@/lib/types'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
import { titleForPath } from './nav'

export function AppLayout() {
  const { role, previewRole } = useAuth()
  const [menuOpen, setMenuOpen] = useState(false)
  const { pathname } = useLocation()
  const title = titleForPath(pathname)

  return (
    <div className="flex h-full">
      <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} />

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar title={title} onOpenMenu={() => setMenuOpen(true)} />

        {!isSupabaseConfigured ? (
          <p className="flex items-center gap-2 border-b border-hairline bg-surface-2 px-4 py-2 text-xs text-ink-2 sm:px-6">
            <Database size={14} aria-hidden className="shrink-0 text-muted" />
            وضع العرض التجريبي — الأرقام المعروضة بيانات تجريبية ثابتة. أضف مفاتيح Supabase في
            ملف&nbsp;
            {/* dir="ltr" stops bidi from reordering the leading dot to the end. */}
            <code dir="ltr" className="rounded bg-surface px-1 py-0.5">
              .env
            </code>
            &nbsp;للاتصال بقاعدة بياناتك.
          </p>
        ) : null}

        {/*
          مبدّل الدور هنا لا في شاشة الإعدادات وحدها.
          كان فيها، فلمّا صارت الإعدادات نفسها محجوبة عن الأدوار المحدودة انغلق
          الباب على من يبدّل: يعاين بدور «خدمة العملاء» فلا يجد سبيلاً للعودة
          إلا بمسح تخزين المتصفّح.
        */}
        {!isSupabaseConfigured ? (
          <div className="flex flex-wrap items-center gap-1.5 border-b border-hairline bg-surface-2 px-4 py-2 sm:px-6">
            <span className="text-[11px] text-muted">عاين اللوحة بدور:</span>
            {ROLES_IN_ORDER.map((key) => (
              <button
                key={key}
                type="button"
                onClick={() => previewRole(key as AdminRole)}
                aria-pressed={role === key}
                className={cn(
                  'cursor-pointer rounded-md px-2 py-0.5 text-[11px] transition-colors',
                  role === key
                    ? 'bg-accent text-accent-ink'
                    : 'text-ink-2 hover:bg-surface hover:text-ink',
                )}
              >
                {ROLE_LABEL[key]}
              </button>
            ))}
          </div>
        ) : null}

        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
