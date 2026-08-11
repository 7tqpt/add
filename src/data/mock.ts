import type {
  AppSettings,
  AppUser,
  AppVersion,
  DailyBreakdown,
  MetricPoint,
  Platform,
  PushNotification,
  UserStatus,
} from '@/lib/types'

/**
 * Demo dataset used whenever Supabase env vars are absent.
 *
 * Everything is generated from a fixed seed so the numbers stay identical
 * across renders, reloads and screenshots — a dashboard whose KPIs shuffle on
 * every refresh is impossible to review.
 */

/** mulberry32 — small, fast, deterministic. */
function makeRng(seed: number) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const rng = makeRng(20260811)

const pick = <T,>(items: readonly T[]): T => items[Math.floor(rng() * items.length)]

const between = (min: number, max: number) => min + rng() * (max - min)

const intBetween = (min: number, max: number) => Math.round(between(min, max))

function isoDay(daysAgo: number): string {
  const d = new Date()
  d.setHours(12, 0, 0, 0)
  d.setDate(d.getDate() - daysAgo)
  return d.toISOString().slice(0, 10)
}

function isoAt(daysAgo: number, hour = 10): string {
  const d = new Date()
  d.setHours(hour, intBetween(0, 59), 0, 0)
  d.setDate(d.getDate() - daysAgo)
  return d.toISOString()
}

/** Longest range any screen asks for; shorter ranges slice the tail. */
const HISTORY_DAYS = 90

const FIRST_NAMES = [
  'أحمد', 'محمد', 'عبدالله', 'خالد', 'يوسف', 'عمر', 'سعيد', 'طارق', 'بلال', 'كريم',
  'فاطمة', 'مريم', 'نورة', 'سارة', 'ليلى', 'هدى', 'رنا', 'أمل', 'دعاء', 'ريم',
]

const LAST_NAMES = [
  'العتيبي', 'الحربي', 'القحطاني', 'الشمري', 'الزهراني', 'المالكي', 'الدوسري',
  'بن سالم', 'العمري', 'الأنصاري', 'حسن', 'إبراهيم', 'منصور', 'صالح',
]

const COUNTRIES = [
  'السعودية', 'مصر', 'الإمارات', 'المغرب', 'الأردن', 'الكويت', 'الجزائر', 'قطر', 'تونس', 'عُمان',
]

const APP_VERSIONS = ['3.4.0', '3.3.2', '3.3.0', '3.2.1', '3.1.0']

const STATUS_WEIGHTS: { status: UserStatus; weight: number }[] = [
  { status: 'active', weight: 0.78 },
  { status: 'pending', weight: 0.14 },
  { status: 'suspended', weight: 0.08 },
]

function weightedStatus(): UserStatus {
  const roll = rng()
  let acc = 0
  for (const entry of STATUS_WEIGHTS) {
    acc += entry.weight
    if (roll <= acc) return entry.status
  }
  return 'active'
}

function transliterate(index: number): string {
  return `user${(index + 137).toString().padStart(4, '0')}`
}

export const mockUsers: AppUser[] = Array.from({ length: 84 }, (_, i) => {
  const createdDaysAgo = intBetween(0, 320)
  const status = weightedStatus()
  // Pending accounts never signed in; suspended ones went quiet a while back.
  const lastSeenDaysAgo =
    status === 'pending'
      ? null
      : status === 'suspended'
        ? intBetween(20, Math.max(21, createdDaysAgo))
        : intBetween(0, Math.min(14, Math.max(1, createdDaysAgo)))

  return {
    id: `usr_${(1000 + i).toString(36)}${i}`,
    full_name: `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`,
    email: `${transliterate(i)}@example.com`,
    phone: rng() > 0.25 ? `+9665${intBetween(10_000_000, 99_999_999)}` : null,
    platform: (rng() > 0.42 ? 'android' : 'ios') as Platform,
    country: pick(COUNTRIES),
    status,
    app_version: pick(APP_VERSIONS),
    sessions_count: status === 'pending' ? 0 : intBetween(1, 480),
    created_at: isoAt(createdDaysAgo, intBetween(6, 23)),
    last_seen_at: lastSeenDaysAgo === null ? null : isoAt(lastSeenDaysAgo, intBetween(6, 23)),
  }
})

/**
 * Installs per day, split by platform. Built as a gently rising trend plus a
 * weekend dip so the shape reads like real product data rather than noise.
 */
export const mockInstallsByDay: DailyBreakdown[] = Array.from(
  { length: HISTORY_DAYS },
  (_, i) => {
    const daysAgo = HISTORY_DAYS - 1 - i
    const date = isoDay(daysAgo)
    const trend = 180 + i * 2.4
    const weekend = [5, 6].includes(new Date(date).getDay()) ? 0.82 : 1
    const total = Math.round(trend * weekend * between(0.86, 1.14))
    const android = Math.round(total * between(0.54, 0.62))
    return { date, ios: total - android, android }
  },
)

export const mockSessionsByDay: MetricPoint[] = mockInstallsByDay.map((day, i) => ({
  date: day.date,
  value: Math.round((day.ios + day.android) * between(9.5, 12.5) + i * 12),
}))

export const mockRevenueByDay: MetricPoint[] = mockInstallsByDay.map((day) => ({
  date: day.date,
  value: Math.round((day.ios + day.android) * between(11, 18)),
}))

export const mockNotifications: PushNotification[] = [
  {
    id: 'ntf_01',
    title: 'خصم 25% لنهاية الأسبوع',
    body: 'استخدم كود WEEKEND25 عند إتمام الطلب قبل يوم الأحد.',
    audience: 'all',
    status: 'sent',
    scheduled_at: null,
    sent_at: isoAt(1, 19),
    recipients: 18420,
    opened: 7361,
  },
  {
    id: 'ntf_02',
    title: 'تحديث جديد متاح',
    body: 'النسخة 3.4.0 أصبحت متاحة مع تحسينات في السرعة وإصلاح الأعطال.',
    audience: 'ios',
    status: 'sent',
    scheduled_at: null,
    sent_at: isoAt(4, 12),
    recipients: 7940,
    opened: 2418,
  },
  {
    id: 'ntf_03',
    title: 'اشتقنا لك 👋',
    body: 'لم نرَك منذ فترة — تفقّد الجديد في التطبيق.',
    audience: 'inactive',
    status: 'scheduled',
    scheduled_at: isoAt(-2, 18),
    sent_at: null,
    recipients: 3120,
    opened: 0,
  },
  {
    id: 'ntf_04',
    title: 'صيانة مجدولة',
    body: 'سيتوقف التطبيق مؤقتاً يوم الجمعة من 2 إلى 4 فجراً.',
    audience: 'all',
    status: 'draft',
    scheduled_at: null,
    sent_at: null,
    recipients: 0,
    opened: 0,
  },
  {
    id: 'ntf_05',
    title: 'تنبيه أمني',
    body: 'يُنصح بتفعيل التحقق بخطوتين من الإعدادات.',
    audience: 'android',
    status: 'failed',
    scheduled_at: null,
    sent_at: isoAt(9, 9),
    recipients: 0,
    opened: 0,
  },
  {
    id: 'ntf_06',
    title: 'مرحباً بك في التطبيق',
    body: 'ابدأ بإكمال ملفك الشخصي للحصول على توصيات أفضل.',
    audience: 'active',
    status: 'sent',
    scheduled_at: null,
    sent_at: isoAt(14, 11),
    recipients: 15230,
    opened: 8102,
  },
]

export const mockVersions: AppVersion[] = [
  {
    id: 'ver_01',
    platform: 'ios',
    version: '3.4.0',
    build: 3401,
    released_at: isoAt(6, 10),
    force_update: false,
    rollout_percent: 100,
    notes: 'تحسين سرعة الإقلاع بنسبة 30% وإصلاح تعطّل شاشة الدفع.',
  },
  {
    id: 'ver_02',
    platform: 'android',
    version: '3.4.0',
    build: 3402,
    released_at: isoAt(5, 10),
    force_update: false,
    rollout_percent: 60,
    notes: 'نفس تحديثات iOS مع دعم الوضع الليلي على أندرويد 15.',
  },
  {
    id: 'ver_03',
    platform: 'ios',
    version: '3.3.2',
    build: 3322,
    released_at: isoAt(28, 10),
    force_update: true,
    rollout_percent: 100,
    notes: 'إصلاح ثغرة في تجديد الجلسة — التحديث إجباري.',
  },
  {
    id: 'ver_04',
    platform: 'android',
    version: '3.3.0',
    build: 3300,
    released_at: isoAt(44, 10),
    force_update: false,
    rollout_percent: 100,
    notes: 'إضافة الإشعارات داخل التطبيق.',
  },
]

export const mockSettings: AppSettings = {
  maintenance_mode: false,
  maintenance_message: 'نقوم بأعمال صيانة سريعة، عُد إلينا خلال ساعة.',
  allow_signups: true,
  min_ios_version: '3.3.2',
  min_android_version: '3.2.0',
  support_email: 'support@example.com',
  default_locale: 'ar',
}

export const mockCrashFreeRate = 0.9942
