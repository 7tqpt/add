import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { Database } from 'lucide-react'
import { isSupabaseConfigured } from '@/lib/supabase'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
import { titleForPath } from './nav'

export function AppLayout() {
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

        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
