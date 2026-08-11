import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/cn'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md'

const VARIANTS: Record<Variant, string> = {
  primary:
    'bg-series-1 text-white hover:brightness-110 active:brightness-95 disabled:hover:brightness-100',
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
    <button
      className={cn(
        'inline-flex cursor-pointer items-center justify-center rounded-lg font-medium whitespace-nowrap transition-[background-color,filter,color] disabled:cursor-not-allowed disabled:opacity-55',
        VARIANTS[variant],
        SIZES[size],
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  )
}
