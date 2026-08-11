import {
  Bell,
  LayoutDashboard,
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
  { to: '/notifications', label: 'الإشعارات', icon: Bell },
  { to: '/versions', label: 'إصدارات التطبيق', icon: Smartphone },
  { to: '/settings', label: 'الإعدادات', icon: Settings },
]
