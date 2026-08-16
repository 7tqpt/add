import { useEffect, useRef, useState } from 'react'
import { LogOut, Moon, Sun, UserRound } from 'lucide-react'
import { BrandMark } from '@/components/brand/Brand'
import { useAuth } from '@/context/AuthContext'
import { useTheme } from '@/context/ThemeContext'
import { ROLE_LABEL } from '@/lib/permissions'

/**
 * قائمة المستخدم المنسدلة.
 *
 * وهي `<button>` وقائمةٌ بجانبها لا مكتبةٌ كاملة: الحاجة ثلاثة بنود، وجلبُ
 * مكتبةِ قوائم لأجلها يضيف كيلوبايتاتٍ وسلوكاً لا نتحكّم فيه.
 *
 * والمطلوب من أي قائمةٍ منسدلة ثلاثةٌ تُنسى كثيراً: تُغلق بمفتاح الهروب،
 * وتُغلق بالنقر خارجها، ويعود التركيز إلى زرّها بعد الإغلاق. وبدون الثالثة
 * يقفز التركيز إلى أوّل الصفحة فيتيه من يتنقّل بلوحة المفاتيح.
 */
export function UserMenu() {
  const { user, role, signOut } = useAuth()
  const { theme, toggle } = useTheme()
  const [open, setOpen] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const box = useRef<HTMLDivElement | null>(null)
  const trigger = useRef<HTMLButtonElement | null>(null)

  useEffect(() => {
    if (!open) return

    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setOpen(false)
        trigger.current?.focus()
      }
    }
    function onPointer(event: PointerEvent) {
      if (!box.current?.contains(event.target as Node)) setOpen(false)
    }

    document.addEventListener('keydown', onKey)
    // `pointerdown` لا `click`: النقر خارج القائمة قد يقع على زرٍّ آخر،
    // و`click` يصل بعد أن يكون الزرّ الآخر قد عمل والقائمة ما زالت مفتوحة.
    document.addEventListener('pointerdown', onPointer)
    return () => {
      document.removeEventListener('keydown', onKey)
      document.removeEventListener('pointerdown', onPointer)
    }
  }, [open])

  if (!user) return null

  async function handleSignOut() {
    setSigningOut(true)
    try {
      await signOut()
    } finally {
      setSigningOut(false)
      setOpen(false)
    }
  }

  return (
    <div ref={box} className="relative">
      {/*
        الشعار في قرص الحساب لا حرفُ الاسم.

        والحرف كان يفرّق بين مستخدمٍ وآخر، والشعار لا يفرّق — لكنّ اللوحة لا
        تعرض إلا حساباً واحداً في وقت، وهو حسابُ من يجلس أمامها. فما يميّزه
        عن غيره ليس بحاجةٍ إلى رمز، والبريد يظهر كاملاً بمجرّد فتح القائمة.
      */}
      <button
        ref={trigger}
        type="button"
        onClick={() => setOpen((on) => !on)}
        aria-haspopup="menu"
        aria-expanded={open}
        // النصّ المرئي كلمةٌ واحدة، والبريد لا يظهر إلا داخل القائمة. ولذلك
        // يحمله `aria-label`: قارئ الشاشة يسمع «Profile» وحدها فلا يعرف أيّ
        // حسابٍ هو، ومن يدير حسابين يحتاج أن يعرف قبل أن يضغط الخروج.
        //
        // والوصف يبدأ بالكلمة المرئية نفسها لا بترجمتها: من يأمر بصوته يقول
        // ما يقرأ، فلو خالف الوصفُ المكتوبَ لم يجد الأمرُ هدفه.
        aria-label={`Profile — ${user.email}`}
        className="icon-press tilt-group flex cursor-pointer items-center gap-2 rounded-full border border-hairline bg-surface-2 py-1 ps-1 pe-2.5 transition-colors hover:border-[color-mix(in_oklab,var(--accent)_40%,var(--border))]"
      >
        <span className="tilt-hover inline-flex">
          <BrandMark size={28} />
        </span>
        {/* `dir="ltr"` لكلمةٍ لاتينية داخل صفحةٍ عربية: الكلمة وحدها تُرتَّب
            صحيحةً بلا توجيه، لكنّ التوجيه الصريح يحميها لو أُضيف إليها يوماً
            رقمٌ أو نقطة — وعندها يقلبهما محرّك الاتجاه بلا تحذير. */}
        <span
          dir="ltr"
          className="hidden text-xs font-medium text-ink-2 sm:inline"
        >
          Profile
        </span>
      </button>

      {open ? (
        <div
          role="menu"
          aria-label="قائمة الحساب"
          className="glass-panel absolute top-11 end-0 z-40 w-60 overflow-hidden rounded-xl border border-hairline shadow-xl"
        >
          <div className="flex items-center gap-2.5 border-b border-hairline px-3 py-3">
            <BrandMark size={38} />
            <span className="min-w-0">
              <span dir="ltr" className="block truncate text-start text-xs font-medium text-ink">
                {user.email}
              </span>
              <span className="mt-0.5 flex items-center gap-1 text-[11px] text-muted">
                <UserRound size={11} aria-hidden />
                {role ? ROLE_LABEL[role] : 'بلا صلاحية'}
              </span>
            </span>
          </div>

          <button
            type="button"
            role="menuitem"
            onClick={toggle}
            className="icon-press flex w-full cursor-pointer items-center gap-2.5 px-3 py-2.5 text-start text-xs text-ink-2 transition-colors hover:bg-surface-2 hover:text-ink"
          >
            {theme === 'dark' ? <Sun size={15} aria-hidden /> : <Moon size={15} aria-hidden />}
            {theme === 'dark' ? 'الوضع النهاري' : 'الوضع الليلي'}
          </button>

          <button
            type="button"
            role="menuitem"
            onClick={handleSignOut}
            disabled={signingOut}
            className="icon-press flex w-full cursor-pointer items-center gap-2.5 border-t border-hairline px-3 py-2.5 text-start text-xs transition-colors hover:bg-surface-2 disabled:opacity-55"
            style={{ color: 'var(--critical)' }}
          >
            <LogOut size={15} aria-hidden />
            {signingOut ? 'جارٍ الخروج…' : 'تسجيل الخروج'}
          </button>
        </div>
      ) : null}
    </div>
  )
}
