import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/cn'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md'

const VARIANTS: Record<Variant, string> = {
  primary:
    'bg-accent text-accent-ink hover:brightness-110 active:brightness-95 disabled:hover:brightness-100',
  secondary:
    'border border-hairline bg-surface text-ink hover:bg-surface-2 disabled:hover:bg-surface',
  ghost: 'text-ink-2 hover:bg-surface-2 hover:text-ink disabled:hover:bg-transparent',
  danger: 'bg-critical text-white hover:brightness-110 disabled:hover:brightness-100',
}

const SIZES: Record<Size, string> = {
  // 36px / 40px tall — both clear the 24px minimum hit target with room to spare.
  sm: 'h-9 px-3 text-xs gap-1.5',
  md: 'h-10 px-4 text-sm gap-2',
}

// `icon-press` هنا لا في كل موضع استعمال: الزرّ واحدٌ في المشروع كلّه،
// فوضعُ ردّ الفعل في أساسه يجعله يشمل كل زرٍّ حاضرٍ ومستقبَل بلا أن يُنسى.
const BASE =
  'icon-press inline-flex cursor-pointer items-center justify-center rounded-lg font-medium whitespace-nowrap transition-[background-color,filter,color] disabled:cursor-not-allowed disabled:opacity-55'

/**
 * أصناف الزرّ لعنصر ليس `<button>`.
 *
 * الرابط الذي يفتح في تبويب جديد يجب أن يكون `<a href>` فعلاً لا زرّاً يقلّده:
 * الزرّ لا يُفتح بضغطة وسطى ولا «فتح في تبويب جديد»، وقارئ الشاشة يسمّيه زرّاً
 * فلا يتوقّع المستخدم مغادرة الصفحة. وتحويل Button إلى مكوّن متعدّد الأشكال
 * ثمنه أنواع معقّدة في كل موضع استعمال، فالأرخص أن تُعار الأصناف.
 */
export function buttonClass(variant: Variant = 'secondary', size: Size = 'md', className?: string) {
  return cn(BASE, VARIANTS[variant], SIZES[size], className)
}

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  children: ReactNode
}

export function Button({
  variant = 'secondary',
  size = 'md',
  className,
  children,
  ...rest
}: ButtonProps) {
  return (
    <button className={buttonClass(variant, size, className)} {...rest}>
      {children}
    </button>
  )
}
