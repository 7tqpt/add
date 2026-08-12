import { Link, Outlet, useLocation } from 'react-router-dom'
import { Lock } from 'lucide-react'
import { Card } from '@/components/ui/Card'
import { useAuth } from '@/context/AuthContext'
import { AREA_LABEL, ROLE_LABEL } from '@/lib/permissions'
import { areaForPath } from './nav'

/**
 * يمنع فتح شاشةٍ خارج صلاحية الدور.
 *
 * إخفاء البند من القائمة الجانبية ليس منعاً: العنوان يبقى قابلاً للكتابة، ومن
 * حفظ رابطاً حين كان دوره أوسع يفتحه بعد تضييقه. وبلا هذا الحارس تُفتح الشاشة
 * فارغةً — RLS تمنع البيانات لا الصفحة — فيظنّها المستخدم عطلاً ويفتح تذكرة.
 *
 * الحارس للوضوح، والمنع الفعلي في RLS: لا شيء هنا يمنع طلباً يُرسَل من خارج
 * اللوحة أصلاً.
 */
export function AreaGuard() {
  const { role, can } = useAuth()
  const location = useLocation()
  const area = areaForPath(location.pathname)

  if (area && !can(area, 'read')) {
    return (
      <Card className="p-6 text-center sm:p-8">
        <span
          aria-hidden
          className="mx-auto flex h-11 w-11 items-center justify-center rounded-full"
          style={{ background: 'color-mix(in oklab, var(--warning) 16%, transparent)' }}
        >
          <Lock size={20} style={{ color: 'var(--text-primary)' }} />
        </span>

        <h1 className="mt-4 text-sm font-semibold text-ink">هذا القسم خارج صلاحيتك</h1>

        <p className="mt-2 text-xs leading-6 text-ink-2">
          «{AREA_LABEL[area]}» غير متاح لدور{' '}
          <span className="font-medium">{role ? ROLE_LABEL[role] : '—'}</span>. راجع مالك
          المنصة إن كنت تحتاج الوصول إليه.
        </p>

        <Link
          to="/"
          className="mt-4 inline-block text-xs font-medium text-accent underline underline-offset-4"
        >
          العودة إلى لوحة المعلومات
        </Link>
      </Card>
    )
  }

  return <Outlet />
}
