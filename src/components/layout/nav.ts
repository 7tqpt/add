import type { AdminArea } from '@/lib/types'
import type { Tone } from '@/components/charts/StatTile'
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
  Ticket,
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
  /**
   * صبغة القسم. يأخذها رأس الصفحة وقرصُ الأيقونة في القائمة، فيعرف المستخدم
   * أين هو من لونٍ قبل أن يقرأ عنواناً.
   *
   * وهي للمجموعة لا للبند: ستّ عشرة صبغةً متجاورة تُقرأ فوضى، وستٌّ تُقرأ
   * نظاماً — واللون هنا تصنيفٌ لا تزيين.
   */
  tone: Tone
}

export interface NavGroup {
  /** null for the first group, which carries the dashboard alone. */
  label: string | null
  items: NavItem[]
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: null,
    items: [{ to: '/', label: 'لوحة المعلومات', icon: LayoutDashboard, area: 'bookings', tone: 'azure' }],
  },
  {
    label: 'الحجوزات',
    items: [
      { to: '/bookings', label: 'الحجوزات', icon: CalendarCheck, area: 'bookings', tone: 'azure' },
      { to: '/plans', label: 'خطط الأعراس', icon: HeartHandshake, area: 'bookings', tone: 'azure' },
    ],
  },
  {
    label: 'الأطراف',
    items: [
      { to: '/users', label: 'العملاء', icon: Users, area: 'directory', tone: 'cyan' },
      { to: '/providers', label: 'مقدّمو الخدمة', icon: BriefcaseBusiness, area: 'directory', tone: 'cyan' },
      { to: '/catalog', label: 'الأقسام والخدمات', icon: LayoutList, area: 'catalog', tone: 'cyan' },
    ],
  },
  {
    label: 'المالية',
    items: [
      { to: '/payments', label: 'عمليات الدفع', icon: CreditCard, area: 'finance', tone: 'emerald' },
      { to: '/settlements', label: 'مستحقات الشركاء', icon: Banknote, area: 'finance', tone: 'emerald' },
      { to: '/promotions', label: 'الاشتراكات والإعلانات', icon: Megaphone, area: 'finance', tone: 'emerald' },
      // مع المالية لا مع التسويق: الكوبون **مصروف** يُخصم من عمولة المنصّة،
      // فمن يملك قرار المال يملك قرار الحملة.
      { to: '/coupons', label: 'أكواد الخصم', icon: Ticket, area: 'finance', tone: 'emerald' },
    ],
  },
  {
    label: 'الثقة',
    items: [
      { to: '/support', label: 'خدمة العملاء', icon: LifeBuoy, area: 'support', tone: 'violet' },
      { to: '/disputes', label: 'النزاعات', icon: Scale, area: 'trust', tone: 'violet' },
      { to: '/reviews', label: 'التقييمات', icon: Star, area: 'trust', tone: 'violet' },
    ],
  },
  {
    label: 'التشغيل',
    items: [
      { to: '/notifications', label: 'الإشعارات', icon: Bell, area: 'ops', tone: 'navy' },
      { to: '/versions', label: 'إصدارات التطبيق', icon: Smartphone, area: 'ops', tone: 'navy' },
      { to: '/audit', label: 'سجل العمليات', icon: ScrollText, area: 'settings', tone: 'navy' },
      { to: '/settings', label: 'الإعدادات', icon: Settings, area: 'settings', tone: 'navy' },
    ],
  },
]

const ALL_ITEMS: NavItem[] = NAV_GROUPS.flatMap((group) => group.items)

/**
 * القسم الذي يقع فيه مسارٌ ما — بعنوانه وأيقونته وصبغته.
 *
 * ومسارات التفاصيل ليست في القائمة، فتُطابَق بالسابقة: `/bookings/abc` يبقى
 * «الحجوزات» بصبغتها، فلا ينقلب رأس الصفحة لوناً آخر حين تُفتح تفاصيل حجز.
 */
export function sectionForPath(pathname: string): NavItem {
  const exact = ALL_ITEMS.find((item) => item.to === pathname)
  if (exact) return exact

  const prefixed = ALL_ITEMS.find((item) => item.to !== '/' && pathname.startsWith(`${item.to}/`))
  return prefixed ?? ALL_ITEMS[0]
}

/** العنوان وحده — لمن لا يحتاج غيره. */
export function titleForPath(pathname: string): string {
  return sectionForPath(pathname).label
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
