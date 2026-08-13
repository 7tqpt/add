import { useState } from 'react'
import { LogOut, Menu, Moon, Sun } from 'lucide-react'
import { useAuth } from '@/context/AuthContext'
import { useTheme } from '@/context/ThemeContext'
import { Button } from '@/components/ui/Button'
import { GlobalSearch } from './GlobalSearch'
import { Icon } from '@/components/ui/Icon'

export function Topbar({ title, onOpenMenu }: { title: string; onOpenMenu: () => void }) {
  const { user, signOut } = useAuth()
  const { theme, toggle } = useTheme()
  const [signingOut, setSigningOut] = useState(false)

  async function handleSignOut() {
    setSigningOut(true)
    try {
      await signOut()
    } finally {
      setSigningOut(false)
    }
  }

  return (
    <header className="sticky top-0 z-20 flex h-16 shrink-0 items-center justify-between gap-3 border-b border-hairline bg-surface/90 px-4 backdrop-blur sm:px-6">
      <div className="flex min-w-0 items-center gap-2">
        <button
          type="button"
          onClick={onOpenMenu}
          className="cursor-pointer rounded-md p-2 text-ink-2 hover:bg-surface-2 lg:hidden icon-hoverable icon-btn"
          aria-label="فتح القائمة"
        >
          <Icon icon={Menu} size={18} className="icon-anim" />
        </button>
        <h1 className="truncate text-base font-semibold text-ink">{title}</h1>
      </div>

      <GlobalSearch />

      <div className="flex shrink-0 items-center gap-1.5">
        <button
          type="button"
          onClick={toggle}
          className="cursor-pointer rounded-md p-2 text-ink-2 hover:bg-surface-2 icon-hoverable icon-btn"
          aria-label={theme === 'dark' ? 'التبديل إلى الوضع النهاري' : 'التبديل إلى الوضع الليلي'}
        >
          {theme === 'dark' ? (
            <Icon icon={Sun} size={17} className="icon-anim" />
          ) : (
            <Icon icon={Moon} size={17} className="icon-anim" />
          )}
        </button>

        {user ? (
          <div className="flex items-center gap-2">
            <span
              aria-hidden
              className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-xs font-semibold text-ink-2"
            >
              {user.name.trim().charAt(0).toUpperCase() || '؟'}
            </span>
            <span className="hidden text-xs text-ink-2 sm:inline">{user.email}</span>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleSignOut}
              disabled={signingOut}
              aria-label="تسجيل الخروج"
            >
              <span className="icon-hoverable icon-btn">
                <Icon icon={LogOut} size={15} className="icon-anim" />
              </span>
              <span className="hidden sm:inline">خروج</span>
            </Button>
          </div>
        ) : null}
      </div>
    </header>
  )
}
