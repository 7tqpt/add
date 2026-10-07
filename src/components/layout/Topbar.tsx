import { Menu } from 'lucide-react'
import { GlobalSearch } from './GlobalSearch'
import { UserMenu } from './UserMenu'
import type { NavItem } from './nav'

/**
 * التحيّةُ بحسب ساعة الجهاز — «صباح الخير» قبل الظهر، و«مساء الخير» بعده.
 * ودالّةٌ مستقلّة ليُقاس حدُّها بلا شاشة.
 */
export function greeting(now: Date = new Date()): string {
  return now.getHours() < 12 ? 'صباح الخير' : 'مساء الخير'
}

/**
 * رأس الصفحة — على صورة (أ) «المخمل»: العنوانُ على ورق الصفحة، والبحثُ
 * والحسابُ في طرفه الآخر. **وفي «نظرة عامة» التحيّةُ مكانَ العنوان** وسطرٌ
 * تحتها، كما في الصورة.
 *
 * (وكان قرصاً مصبوغاً بصبغة القسم ينقلب عند كلّ تبدّل، ووشاحاً ملوّناً — وكلاهما
 * من العهد الأزرق: في (أ) اللونُ في القائمة، والرأسُ هادئ.)
 */
export function Topbar({ section, onOpenMenu }: { section: NavItem; onOpenMenu: () => void }) {
  const home = section.to === '/'

  return (
    <header className="topbar-glass sticky top-0 z-20 flex h-20 shrink-0 items-center justify-between gap-3 px-4 sm:px-7">
      <div className="flex min-w-0 items-center gap-2">
        <button
          type="button"
          onClick={onOpenMenu}
          className="icon-press cursor-pointer rounded-md p-2 text-ink-2 hover:bg-surface-2 lg:hidden"
          aria-label="فتح القائمة"
        >
          <Menu size={18} aria-hidden />
        </button>

        <div key={section.to} className="title-in min-w-0">
          <h1 data-page-title className="truncate text-2xl font-bold text-ink">
            {home ? greeting() : section.label}
          </h1>
          {home ? <p className="truncate text-sm text-muted">هذا ما يحتاج متابعتك اليوم</p> : null}
        </div>
      </div>

      <GlobalSearch />

      <div className="flex shrink-0 items-center gap-1.5">
        <UserMenu />
      </div>
    </header>
  )
}
