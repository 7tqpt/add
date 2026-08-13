import type { AdminArea } from '@/lib/types'
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
  /**
   * المجال الذي يحكم ظهور هذا البند. القائمة والحارس يقرآن منه معاً، فلا يقع
   * ما وقع لو كُتب الشرطان منفصلين: بندٌ مخفيّ يفتحه من يكتب مساره بيده.
   */
  area: AdminArea
}

export interface NavGroup {
  /** null for the first group, which carries the dashboard alone. */
  label: string | null
  items: NavItem[]
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: null,
    items: [{ to: '/', label: 'لوحة المعلومات', icon: LayoutDashboard, area: 'bookings' }],
  },
  {
    label: 'الحجوزات',
    items: [
      { to: '/bookings', label: 'الحجوزات', icon: CalendarCheck, area: 'bookings' },
      { to: '/plans', label: 'خطط الأعراس', icon: HeartHandshake, area: 'bookings' },
    ],
  },
  {
    label: 'الأطراف',
    items: [
      { to: '/users', label: 'العملاء', icon: Users, area: 'directory' },
      { to: '/providers', label: 'مقدّمو الخدمة', icon: BriefcaseBusiness, area: 'directory' },
      { to: '/catalog', label: 'الأقسام والخدمات', icon: LayoutList, area: 'catalog' },
    ],
  },
  {
    label: 'المالية',
    items: [
      { to: '/payments', label: 'عمليات الدفع', icon: CreditCard, area: 'finance' },
      { to: '/settlements', label: 'مستحقات الشركاء', icon: Banknote, area: 'finance' },
      { to: '/promotions', label: 'الاشتراكات والإعلانات', icon: Megaphone, area: 'finance' },
    ],
  },
  {
    label: 'الثقة',
    items: [
      { to: '/support', label: 'خدمة العملاء', icon: LifeBuoy, area: 'support' },
      { to: '/disputes', label: 'النزاعات', icon: Scale, area: 'trust' },
      { to: '/reviews', label: 'التقييمات', icon: Star, area: 'trust' },
    ],
  },
  {
    label: 'التشغيل',
    items: [
      { to: '/notifications', label: 'الإشعارات', icon: Bell, area: 'ops' },
      { to: '/versions', label: 'إصدارات التطبيق', icon: Smartphone, area: 'ops' },
      { to: '/audit', label: 'سجل العمليات', icon: ScrollText, area: 'settings' },
      { to: '/settings', label: 'الإعدادات', icon: Settings, area: 'settings' },
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

/** المجال الذي يحكم مساراً — يشمل مسارات التفاصيل التي ليست في القائمة. */
export function areaForPath(pathname: string): AdminArea | null {
  const exact = ALL_ITEMS.find((item) => item.to === pathname)
  if (exact) return exact.area
  const prefixed = ALL_ITEMS.find(
    (item) => item.to !== '/' && pathname.startsWith(`${item.to}/`),
  )
  return prefixed?.area ?? null
}
