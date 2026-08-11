import { Link } from 'react-router-dom'

export function NotFoundPage() {
  return (
    <div className="flex min-h-full flex-col items-center justify-center gap-3 p-8 text-center">
      <p className="tnum text-3xl font-semibold text-ink">404</p>
      <p className="text-sm text-ink-2">الصفحة المطلوبة غير موجودة.</p>
      <Link to="/" className="text-sm font-medium text-series-1 underline underline-offset-4">
        العودة إلى لوحة المعلومات
      </Link>
    </div>
  )
}
