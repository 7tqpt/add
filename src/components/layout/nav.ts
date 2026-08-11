import {
  Bell,
  BriefcaseBusiness,
  CreditCard,
  LayoutDashboard,
  LifeBuoy,
  ScrollText,
  Settings,
  Smartphone,
  Users,
  type LucideIcon,
} from 'lucide-react'

export interface NavItem {
  to: string
  label: string
  icon: LucideIcon
}

export const NAV_ITEMS: NavItem[] = [
  { to: '/', label: 'لوحة المعلومات', icon: LayoutDashboard },
  { to: '/users', label: 'المستخدمون', icon: Users },
  { to: '/providers', label: 'مقدّمو الخدمة', icon: BriefcaseBusiness },
  { to: '/payments', label: 'عمليات الدفع', icon: CreditCard },
  { to: '/tickets', label: 'البلاغات والدعم', icon: LifeBuoy },
  { to: '/notifications', label: 'الإشعارات', icon: Bell },
  { to: '/versions', label: 'إصدارات التطبيق', icon: Smartphone },
  { to: '/audit', label: 'سجل العمليات', icon: ScrollText },
  { to: '/settings', label: 'الإعدادات', icon: Settings },
]

/**
 * Page title for the top bar. Detail routes are not in the sidebar, so they are
 * matched by prefix — `/users/abc` still reads as "المستخدمون".
 */
export function titleForPath(pathname: string): string {
  const exact = NAV_ITEMS.find((item) => item.to === pathname)
  if (exact) return exact.label

  const prefixed = NAV_ITEMS.find((item) => item.to !== '/' && pathname.startsWith(`${item.to}/`))
  return prefixed?.label ?? 'لوحة التحكم'
}
