import { AlertCircle, Inbox, Loader2 } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { Button } from './Button'

export function Spinner({ className }: { className?: string }) {
  return <Loader2 size={16} className={cn('animate-spin', className)} aria-hidden />
}

export function LoadingBlock({ label = 'جارٍ التحميل…' }: { label?: string }) {
  return (
    <div
      className="flex items-center justify-center gap-2 py-14 text-sm text-muted"
      role="status"
      aria-live="polite"
    >
      <Spinner />
      {label}
    </div>
  )
}

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string
  description?: string
  action?: ReactNode
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-14 text-center">
      <Inbox size={22} className="text-muted" aria-hidden />
      <p className="text-sm font-medium text-ink">{title}</p>
      {description ? <p className="max-w-sm text-xs text-muted">{description}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  )
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-14 text-center">
      <AlertCircle size={22} className="text-[var(--critical)]" aria-hidden />
      <p className="text-sm font-medium text-ink">تعذّر تحميل البيانات</p>
      <p className="max-w-sm text-xs text-muted">{message}</p>
      {onRetry ? (
        <Button size="sm" className="mt-2" onClick={onRetry}>
          إعادة المحاولة
        </Button>
      ) : null}
    </div>
  )
}

/** Single transient message anchored bottom-start; dismissed by its owner. */
export function Toast({ message, tone = 'good' }: { message: string; tone?: 'good' | 'critical' }) {
  return (
    <div
      role="status"
      aria-live="polite"
      className={cn(
        'fixed bottom-5 start-5 z-50 flex items-center gap-2 rounded-lg border px-4 py-2.5 text-sm shadow-lg',
        tone === 'good'
          ? 'border-[color-mix(in_oklab,var(--good)_35%,transparent)] bg-surface text-ink'
          : 'border-[color-mix(in_oklab,var(--critical)_35%,transparent)] bg-surface text-ink',
      )}
    >
      <span
        aria-hidden
        className="h-2 w-2 shrink-0 rounded-full"
        style={{ background: tone === 'good' ? 'var(--good)' : 'var(--critical)' }}
      />
      {message}
    </div>
  )
}
