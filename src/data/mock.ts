import type {
  AdminAccount,
  AppSettings,
  AppUser,
  AppVersion,
  DailyBreakdown,
  MetricPoint,
  DocumentStatus,
  DocumentType,
  Platform,
  ProviderDocument,
  ProviderReview,
  ProviderService,
  ProviderStatus,
  Purchase,
  PurchaseStatus,
  PushNotification,
  ServiceProvider,
  SupportTicket,
  TicketCategory,
  TicketMessage,
  TicketPriority,
  TicketStatus,
  UserDevice,
  UserSession,
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

const IOS_DEVICES = ['iPhone 15 Pro', 'iPhone 14', 'iPhone 13 mini', 'iPad Air']
const ANDROID_DEVICES = ['Samsung Galaxy S24', 'Xiaomi 14', 'Pixel 8', 'Oppo Reno 11']

/** Sessions for every user who has actually opened the app. */
export const mockUserSessions: UserSession[] = mockUsers
  .filter((user) => user.status !== 'pending')
  .flatMap((user, userIndex) =>
    Array.from({ length: intBetween(4, 9) }, (_, i) => ({
      id: `ses_${userIndex}_${i}`,
      user_id: user.id,
      started_at: isoAt(i * 2 + intBetween(0, 1), intBetween(7, 23)),
      duration_seconds: intBetween(45, 2700),
      platform: user.platform,
      app_version: user.app_version,
      country: user.country,
    })),
  )

export const mockUserDevices: UserDevice[] = mockUsers
  .filter((user) => user.status !== 'pending')
  .flatMap((user, userIndex) =>
    // Most people have one device; roughly a third also use a second.
    Array.from({ length: rng() > 0.66 ? 2 : 1 }, (_, i) => ({
      id: `dev_${userIndex}_${i}`,
      user_id: user.id,
      model: user.platform === 'ios' ? pick(IOS_DEVICES) : pick(ANDROID_DEVICES),
      os_version: user.platform === 'ios' ? '18.2' : '15',
      platform: user.platform,
      push_enabled: rng() > 0.18,
      last_used_at: user.last_seen_at ?? user.created_at,
    })),
  )

const PRODUCTS = [
  { name: 'اشتراك شهري', amount: 29 },
  { name: 'اشتراك سنوي', amount: 299 },
  { name: 'باقة نقاط 100', amount: 19 },
  { name: 'إزالة الإعلانات', amount: 49 },
]

export const mockPurchases: Purchase[] = mockUsers
  .filter((user) => user.status === 'active')
  .flatMap((user, userIndex) =>
    Array.from({ length: intBetween(0, 4) }, (_, i) => {
      const product = pick(PRODUCTS)
      const roll = rng()
      return {
        id: `pur_${userIndex}_${i}`,
        user_id: user.id,
        product: product.name,
        amount: product.amount,
        status: (roll > 0.94 ? 'refunded' : roll > 0.9 ? 'failed' : 'paid') as PurchaseStatus,
        created_at: isoAt(intBetween(0, 180), intBetween(8, 22)),
      }
    }),
  )

const TICKET_SUBJECTS: { subject: string; category: TicketCategory }[] = [
  { subject: 'التطبيق يتوقف عند فتح شاشة الدفع', category: 'bug' },
  { subject: 'لم يصلني إيصال الاشتراك', category: 'billing' },
  { subject: 'لا أستطيع تسجيل الدخول برقم الجوال', category: 'account' },
  { subject: 'طلب إضافة الوضع الليلي', category: 'feature' },
  { subject: 'خُصم المبلغ مرتين', category: 'billing' },
  { subject: 'الإشعارات لا تصل على أندرويد', category: 'bug' },
  { subject: 'كيف أحذف حسابي؟', category: 'account' },
  { subject: 'اقتراح: دعم اللغة الفرنسية', category: 'feature' },
]

const TICKET_STATUSES: TicketStatus[] = ['open', 'pending', 'resolved', 'closed']
const TICKET_PRIORITIES: TicketPriority[] = ['urgent', 'high', 'normal', 'low']

export const mockTickets: SupportTicket[] = Array.from({ length: 14 }, (_, i) => {
  const user = mockUsers[i * 3]
  const template = TICKET_SUBJECTS[i % TICKET_SUBJECTS.length]
  const createdDaysAgo = i + intBetween(0, 2)
  return {
    id: `tkt_${(100 + i).toString(36)}`,
    user_id: user.id,
    user_name: user.full_name,
    user_email: user.email,
    subject: template.subject,
    category: template.category,
    status: TICKET_STATUSES[i % TICKET_STATUSES.length],
    priority: TICKET_PRIORITIES[i % TICKET_PRIORITIES.length],
    created_at: isoAt(createdDaysAgo, intBetween(8, 20)),
    updated_at: isoAt(Math.max(0, createdDaysAgo - 1), intBetween(8, 20)),
  }
}).sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

export const mockTicketMessages: TicketMessage[] = mockTickets.flatMap((ticket, i) => {
  const opening: TicketMessage = {
    id: `msg_${i}_0`,
    ticket_id: ticket.id,
    author: 'user',
    author_email: ticket.user_email,
    body: 'السلام عليكم، أواجه هذه المشكلة منذ آخر تحديث للتطبيق. أرجو المساعدة وشكراً.',
    created_at: ticket.created_at,
  }
  if (ticket.status === 'open') return [opening]

  return [
    opening,
    {
      id: `msg_${i}_1`,
      ticket_id: ticket.id,
      author: 'admin' as const,
      author_email: 'support@example.com',
      body: 'وعليكم السلام، شكراً لتواصلك. تم تحويل البلاغ للفريق التقني وسنوافيك بالتحديث قريباً.',
      created_at: ticket.updated_at,
    },
  ]
})

export const PROVIDER_CATEGORIES = [
  'سباكة',
  'كهرباء',
  'تنظيف',
  'تكييف',
  'نجارة',
  'دهان',
  'نقل أثاث',
  'صيانة أجهزة',
]

export const PROVIDER_CITIES = [
  'الرياض',
  'جدة',
  'الدمام',
  'مكة',
  'المدينة',
  'الخبر',
  'أبها',
  'تبوك',
]

const BUSINESS_NAMES = ['الإتقان', 'النخبة', 'الرواد', 'البناء', 'السرعة', 'الأمانة']

const PROVIDER_FIRST = ['سعد', 'ماجد', 'فهد', 'بدر', 'تركي', 'ريان', 'هند', 'لمياء', 'غادة', 'منى']
const PROVIDER_LAST = [
  'السبيعي',
  'الغامدي',
  'الرشيد',
  'البقمي',
  'المطيري',
  'الجهني',
  'العنزي',
  'الخالدي',
]

/** Roughly two thirds active, with a working queue of pending applications. */
function providerStatus(index: number): ProviderStatus {
  if (index % 9 === 0) return 'rejected'
  if (index % 5 === 0) return 'pending'
  if (index % 11 === 0) return 'suspended'
  return 'active'
}

export const mockProviders: ServiceProvider[] = Array.from({ length: 32 }, (_, i) => {
  const status = providerStatus(i + 1)
  const trading = status === 'active' || status === 'suspended'
  const joinedDaysAgo = intBetween(5, 400)

  return {
    id: `prv_${(200 + i).toString(36)}`,
    full_name: `${pick(PROVIDER_FIRST)} ${pick(PROVIDER_LAST)}`,
    business_name: `مؤسسة ${pick(BUSINESS_NAMES)} للخدمات`,
    email: `provider${(i + 1).toString().padStart(3, '0')}@example.com`,
    phone: `+9665${intBetween(20_000_000, 89_999_999)}`,
    category: pick(PROVIDER_CATEGORIES),
    city: pick(PROVIDER_CITIES),
    status,
    rating: trading ? Math.round(between(3.4, 5) * 10) / 10 : 0,
    reviews_count: trading ? intBetween(4, 120) : 0,
    completed_orders: trading ? intBetween(12, 380) : 0,
    total_earnings: trading ? intBetween(1500, 68_000) : 0,
    commission_percent: pick([10, 12, 15, 15, 18, 20]),
    joined_at: isoAt(joinedDaysAgo, intBetween(8, 20)),
    // Verification lands a couple of days after the application.
    verified_at: trading ? isoAt(Math.max(0, joinedDaysAgo - 3), intBetween(8, 20)) : null,
  }
}).sort((a, b) => new Date(b.joined_at).getTime() - new Date(a.joined_at).getTime())

const DOCUMENT_TYPES: DocumentType[] = ['id_card', 'commercial_register', 'certificate']

export const mockProviderDocuments: ProviderDocument[] = mockProviders.flatMap((provider, index) =>
  DOCUMENT_TYPES.map((type, i) => {
    const status: DocumentStatus =
      provider.status === 'pending'
        ? 'pending'
        : provider.status === 'rejected' && type === 'commercial_register'
          ? 'rejected'
          : 'approved'

    return {
      id: `doc_${index}_${i}`,
      provider_id: provider.id,
      type,
      file_name: `${type}-${provider.id}.pdf`,
      status,
      note: status === 'rejected' ? 'السجل التجاري منتهي الصلاحية.' : '',
      uploaded_at: provider.joined_at,
    }
  }),
)

const SERVICE_TEMPLATES = [
  { suffix: 'زيارة معاينة', price: 80, duration: 30 },
  { suffix: 'خدمة أساسية', price: 220, duration: 90 },
  { suffix: 'باقة صيانة شاملة', price: 650, duration: 240 },
]

export const mockProviderServices: ProviderService[] = mockProviders
  .filter((provider) => provider.status === 'active' || provider.status === 'suspended')
  .flatMap((provider, index) =>
    SERVICE_TEMPLATES.map((template, i) => ({
      id: `psv_${index}_${i}`,
      provider_id: provider.id,
      title: `${provider.category} — ${template.suffix}`,
      price: template.price,
      duration_minutes: template.duration,
      active: provider.status === 'active',
    })),
  )

const REVIEW_COMMENTS = [
  'خدمة ممتازة والتزام بالموعد.',
  'العمل جيد لكن التأخير كان ملحوظاً.',
  'أنصح به، سعر مناسب وجودة عالية.',
  'أنهى المهمة بسرعة وترك المكان نظيفاً.',
  'تعامل محترم وشرح المشكلة بوضوح.',
]

export const mockProviderReviews: ProviderReview[] = mockProviders
  .filter((provider) => provider.status === 'active' || provider.status === 'suspended')
  .flatMap((provider, index) =>
    Array.from({ length: intBetween(3, 6) }, (_, i) => ({
      id: `rev_${index}_${i}`,
      provider_id: provider.id,
      user_name: `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`,
      // Scatter around the provider's headline rating rather than repeating it.
      rating: Math.max(1, Math.min(5, Math.round(provider.rating + between(-1.2, 0.6)))),
      comment: pick(REVIEW_COMMENTS),
      created_at: isoAt(intBetween(0, 120), intBetween(9, 21)),
    })),
  )

export const mockAdmins: AdminAccount[] = [
  {
    user_id: 'demo-admin',
    email: 'admin@example.com',
    role: 'owner',
    created_at: isoAt(120, 9),
  },
  {
    user_id: 'adm_2',
    email: 'ops@example.com',
    role: 'admin',
    created_at: isoAt(64, 11),
  },
  {
    user_id: 'adm_3',
    email: 'analyst@example.com',
    role: 'viewer',
    created_at: isoAt(21, 14),
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
