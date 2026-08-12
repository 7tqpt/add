import {
  Banknote,
  Bell,
  BriefcaseBusiness,
  CalendarCheck,
  CreditCard,
  HeartHandshake,
  LayoutDashboard,
  LayoutList,
  LifeBuoy,
  Megaphone,
  ScrollText,
  Scale,
  Settings,
  Smartphone,
  Star,
  Users,
  type LucideIcon,
} from 'lucide-react'

export interface NavItem {
  to: string
  label: string
  icon: LucideIcon
}

export interface NavGroup {
  /** null for the first group, which carries the dashboard alone. */
  label: string | null
  items: NavItem[]
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: null,
    items: [{ to: '/', label: 'لوحة المعلومات', icon: LayoutDashboard }],
  },
  {
    label: 'الحجوزات',
    items: [
      { to: '/bookings', label: 'الحجوزات', icon: CalendarCheck },
      { to: '/plans', label: 'خطط الأعراس', icon: HeartHandshake },
    ],
  },
  {
    label: 'الأطراف',
    items: [
      { to: '/users', label: 'العملاء', icon: Users },
      { to: '/providers', label: 'مقدّمو الخدمة', icon: BriefcaseBusiness },
      { to: '/catalog', label: 'الأقسام والخدمات', icon: LayoutList },
    ],
  },
  {
    label: 'المالية',
    items: [
      { to: '/payments', label: 'عمليات الدفع', icon: CreditCard },
      { to: '/settlements', label: 'مستحقات الشركاء', icon: Banknote },
      { to: '/promotions', label: 'الاشتراكات والإعلانات', icon: Megaphone },
    ],
  },
  {
    label: 'الثقة',
    items: [
      { to: '/support', label: 'خدمة العملاء', icon: LifeBuoy },
      { to: '/disputes', label: 'النزاعات', icon: Scale },
      { to: '/reviews', label: 'التقييمات', icon: Star },
    ],
  },
  {
    label: 'التشغيل',
    items: [
      { to: '/notifications', label: 'الإشعارات', icon: Bell },
      { to: '/versions', label: 'إصدارات التطبيق', icon: Smartphone },
      { to: '/audit', label: 'سجل العمليات', icon: ScrollText },
      { to: '/settings', label: 'الإعدادات', icon: Settings },
    ],
  },
]

const ALL_ITEMS: NavItem[] = NAV_GROUPS.flatMap((group) => group.items)

/**
 * Page title for the top bar. Detail routes are not in the sidebar, so they are
 * matched by prefix — `/bookings/abc` still reads as "الحجوزات".
 */
export function titleForPath(pathname: string): string {
  const exact = ALL_ITEMS.find((item) => item.to === pathname)
  if (exact) return exact.label

  const prefixed = ALL_ITEMS.find((item) => item.to !== '/' && pathname.startsWith(`${item.to}/`))
  return prefixed?.label ?? 'لوحة التحكم'
}
