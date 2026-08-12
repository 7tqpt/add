import type { AdminArea, AdminRole, AreaLevel } from './types'

/**
 * مصفوفة الصلاحيات — نسخةٌ من التي في `supabase/roles.sql`.
 *
 * تكرارها هنا مقصود ومحدود: الواجهة تحتاج أن تعرف قبل الطلب ماذا تعرض وماذا
 * تُخفي، ولا تستطيع سؤال القاعدة عن كل زرّ. لكن **هذه ليست الحماية** — الحماية
 * سياسات RLS، وهي وحدها ما يمنع طلباً يُرسَل من خارج اللوحة.
 *
 * الخطر في النسخة أن تتباعد عن أصلها، فاختبارٌ يقارن هذا الملف بالجدول في
 * قاعدة حقيقية يسقط إن اختلفا.
 */
export const ROLE_AREAS: Record<AdminRole, Record<AdminArea, AreaLevel>> = {
  owner: {
    bookings: 'write', directory: 'write', catalog: 'write', finance: 'write',
    trust: 'write', support: 'write', ops: 'write', settings: 'write', admins: 'write',
  },
  manager: {
    bookings: 'write', directory: 'write', catalog: 'write', finance: 'write',
    trust: 'write', support: 'write', ops: 'write', settings: 'write', admins: 'none',
  },
  operations: {
    bookings: 'write', directory: 'write', catalog: 'write', finance: 'write',
    trust: 'read', support: 'read', ops: 'write', settings: 'read', admins: 'none',
  },
  finance: {
    bookings: 'read', directory: 'read', catalog: 'none', finance: 'write',
    trust: 'read', support: 'none', ops: 'none', settings: 'none', admins: 'none',
  },
  support: {
    bookings: 'read', directory: 'read', catalog: 'read', finance: 'none',
    trust: 'read', support: 'write', ops: 'none', settings: 'none', admins: 'none',
  },
  moderator: {
    bookings: 'read', directory: 'read', catalog: 'read', finance: 'none',
    trust: 'write', support: 'read', ops: 'none', settings: 'none', admins: 'none',
  },
  viewer: {
    bookings: 'read', directory: 'read', catalog: 'read', finance: 'none',
    trust: 'read', support: 'read', ops: 'read', settings: 'read', admins: 'none',
  },
}

export function levelOf(role: AdminRole | null, area: AdminArea): AreaLevel {
  if (!role) return 'none'
  return ROLE_AREAS[role]?.[area] ?? 'none'
}

export function canRead(role: AdminRole | null, area: AdminArea): boolean {
  const level = levelOf(role, area)
  return level === 'read' || level === 'write'
}

export function canWriteArea(role: AdminRole | null, area: AdminArea): boolean {
  return levelOf(role, area) === 'write'
}

export const ROLE_LABEL: Record<AdminRole, string> = {
  owner: 'المالك',
  manager: 'مدير',
  operations: 'مساعد المدير',
  finance: 'محاسب',
  support: 'خدمة العملاء',
  moderator: 'مشرف محتوى',
  viewer: 'مطّلع',
}

export const ROLE_DESCRIPTION: Record<AdminRole, string> = {
  owner: 'كل الصلاحيات، وهو وحده يضيف المسؤولين ويغيّر أدوارهم.',
  manager: 'كل الصلاحيات عدا إدارة المسؤولين.',
  operations: 'المدفوعات والأقسام والخدمات وتوثيق مقدّمي الخدمة والحجوزات.',
  finance: 'المدفوعات والتسويات والاشتراكات وحدها. لا يوثّق أحداً ولا يغيّر الأقسام.',
  support: 'تذاكر خدمة العملاء. يقرأ الحجوزات والعملاء ليجيب عنها، ولا يرى المال.',
  moderator: 'التقييمات والنزاعات. لا يرى المال.',
  viewer: 'قراءة فقط، والمال محجوب عنه.',
}

export const AREA_LABEL: Record<AdminArea, string> = {
  bookings: 'الحجوزات والخطط',
  directory: 'العملاء ومقدّمو الخدمة',
  catalog: 'الأقسام والخدمات',
  finance: 'المدفوعات والمستحقات',
  trust: 'النزاعات والتقييمات',
  support: 'خدمة العملاء',
  ops: 'الإشعارات والإصدارات',
  settings: 'إعدادات المنصة',
  admins: 'إدارة المسؤولين',
}

export const LEVEL_LABEL: Record<AreaLevel, string> = {
  none: 'محجوب',
  read: 'قراءة',
  write: 'تعديل',
}

/** الأدوار مرتّبةً من الأوسع صلاحيةً إلى الأضيق — ترتيب القوائم يتبعه. */
export const ROLES_IN_ORDER: AdminRole[] = [
  'owner',
  'manager',
  'operations',
  'finance',
  'support',
  'moderator',
  'viewer',
]

export const AREAS_IN_ORDER: AdminArea[] = [
  'bookings',
  'directory',
  'catalog',
  'finance',
  'trust',
  'support',
  'ops',
  'settings',
  'admins',
]
