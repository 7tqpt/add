import type {
  AdminAccount,
  AppSettings,
  AppUser,
  AppVersion,
  Booking,
  BookingStatus,
  CancellationPolicy,
  DailyBreakdown,
  Dispute,
  DisputeMessage,
  DisputeStatus,
  DocumentStatus,
  DocumentType,
  Governorate,
  MetricPoint,
  Payment,
  PaymentMethod,
  PaymentStatus,
  PlanStatus,
  Platform,
  Promotion,
  ProviderDocument,
  ProviderService,
  ProviderStatus,
  PushNotification,
  RefundRule,
  Review,
  ServiceCategory,
  ServiceProvider,
  Settlement,
  SubscriptionPlan,
  UserDevice,
  UserSession,
  UserStatus,
  WeddingPlan,
} from '@/lib/types'

/**
 * Demo dataset used whenever Supabase env vars are absent.
 *
 * Generated from a fixed seed so the numbers stay identical across renders,
 * reloads and screenshots — a dashboard whose KPIs shuffle on every refresh is
 * impossible to review. Mirrors supabase/seed.sql so both tell the same story.
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

const HISTORY_DAYS = 90

// ---------------------------------------------------------------------------
// المرجعيات
// ---------------------------------------------------------------------------

const GOVERNORATE_NAMES = [
  'أمانة العاصمة', 'صنعاء', 'عدن', 'تعز', 'الحديدة', 'حضرموت', 'إب', 'ذمار',
  'حجة', 'مأرب', 'لحج', 'أبين', 'شبوة', 'عمران', 'صعدة', 'البيضاء',
  'الضالع', 'المهرة', 'ريمة', 'الجوف',
]

export const mockGovernorates: Governorate[] = GOVERNORATE_NAMES.map((name, i) => ({
  id: `gov_${i + 1}`,
  name,
  sort_order: i + 1,
  is_active: true,
}))

/** المحافظات التي تظهر فيها حركة فعلية في البيانات التجريبية. */
const ACTIVE_GOVERNORATES = GOVERNORATE_NAMES.slice(0, 8)

export const mockCategories: ServiceCategory[] = [
  {
    id: 'cat_halls', name: 'القاعات والخيام', slug: 'halls', sort_order: 1, is_active: true,
    description: 'صالات، خيام، استراحات، السعة، الموقع، الصور، الأسعار والمواعيد المتاحة.',
    custom_fields: [
      { key: 'capacity', label: 'السعة', type: 'number', required: true },
      { key: 'has_parking', label: 'يوجد موقف سيارات', type: 'boolean', required: false },
      { key: 'indoor', label: 'مغلقة', type: 'boolean', required: false },
    ],
  },
  {
    id: 'cat_catering', name: 'الطبخ والضيافة', slug: 'catering', sort_order: 2, is_active: true,
    description: 'طباخين، مطابخ مناسبات، بوفيهات، ذبائح، مندي وحنيذ، قهوة وشاي، وطاقم تقديم.',
    custom_fields: [
      { key: 'guests_capacity', label: 'عدد الأشخاص', type: 'number', required: true },
      { key: 'menu_style', label: 'نمط الوجبة', type: 'text', required: false },
      { key: 'includes_service', label: 'يشمل طاقم التقديم', type: 'boolean', required: false },
    ],
  },
  {
    id: 'cat_artists', name: 'الفنانين والفرق', slug: 'artists', sort_order: 3, is_active: true,
    description: 'فنانين، فرق فنية، منشدين، دي جي، زفة، وفنانين مع معداتهم.',
    custom_fields: [
      { key: 'members', label: 'عدد أفراد الفرقة', type: 'number', required: false },
      { key: 'genre', label: 'النوع', type: 'text', required: false },
    ],
  },
  {
    id: 'cat_sound', name: 'الصوت والمعدات', slug: 'sound', sort_order: 4, is_active: true,
    description: 'سماعات، مكبرات، ميكروفونات، أجهزة دي جي، معدات صوت وحفلات وتأجير المعدات.',
    custom_fields: [{ key: 'coverage_area', label: 'مساحة التغطية', type: 'text', required: false }],
  },
  {
    id: 'cat_photo', name: 'التصوير والإضاءة', slug: 'photography', sort_order: 5, is_active: true,
    description: 'مصورين، فرق تصوير، تصوير فيديو وفوتوغرافي، كاميرات، درون، وإضاءة الحفلات.',
    custom_fields: [
      { key: 'has_drone', label: 'تصوير بالدرون', type: 'boolean', required: false },
      { key: 'team_size', label: 'عدد المصورين', type: 'number', required: false },
    ],
  },
  {
    id: 'cat_support', name: 'الموية والطليع والخدمات المساندة', slug: 'support', sort_order: 6,
    is_active: true,
    description: 'موية، قريح، طليع وأي خدمات مساندة يعتمدها النظام حسب المدينة.',
    custom_fields: [{ key: 'quantity_unit', label: 'وحدة القياس', type: 'text', required: false }],
  },
  {
    id: 'cat_cars', name: 'السيارات', slug: 'cars', sort_order: 7, is_active: true,
    description: 'سيارات للعريس، الزفة، الضيوف، سيارات فخمة، باصات وخدمات نقل.',
    custom_fields: [
      { key: 'car_model', label: 'الطراز', type: 'text', required: false },
      { key: 'seats', label: 'عدد الركاب', type: 'number', required: false },
    ],
  },
  {
    id: 'cat_attire', name: 'الملبوسات', slug: 'attire', sort_order: 8, is_active: true,
    description: 'ملابس العريس والعروس والضيوف والأطفال، شراء، إيجار، تفصيل وإكسسوارات.',
    custom_fields: [{ key: 'mode', label: 'نوع التعامل', type: 'text', required: false }],
  },
  {
    id: 'cat_planners', name: 'متعهدين الحفلات', slug: 'planners', sort_order: 9, is_active: true,
    description: 'تنظيم وتجهيز شامل، باقات، تنسيق الخدمات، الديكور، الصوت، التصوير والزفة.',
    custom_fields: [{ key: 'package_scope', label: 'نطاق الباقة', type: 'text', required: false }],
  },
  {
    id: 'cat_beauty', name: 'التجميل والكوافير', slug: 'beauty', sort_order: 10, is_active: true,
    description: 'مكياج، تسريحات، كوافير، تجهيز العروس وخدمات التجميل.',
    custom_fields: [{ key: 'home_service', label: 'خدمة منزلية', type: 'boolean', required: false }],
  },
  {
    id: 'cat_decor', name: 'الديكور والكوشة والورد', slug: 'decor', sort_order: 11, is_active: true,
    description: 'كوش، ورد، ديكور، خلفيات، طاولات، كراسي وتجهيزات المكان.',
    custom_fields: [{ key: 'style', label: 'الطراز', type: 'text', required: false }],
  },
  {
    id: 'cat_print', name: 'الطباعة', slug: 'printing', sort_order: 12, is_active: true,
    description: 'بطاقات الدعوة، اللوحات، الاستيكرات، التوزيعات، أرقام الطاولات وبطاقات الشكر.',
    custom_fields: [{ key: 'min_quantity', label: 'أقل كمية', type: 'number', required: false }],
  },
]

/** سعر الباقة الأساسية لكل قسم، بالريال اليمني. */
const CATEGORY_BASE_PRICE: Record<string, number> = {
  cat_halls: 300_000, cat_catering: 250_000, cat_artists: 200_000, cat_sound: 90_000, cat_photo: 120_000,
  cat_support: 40_000, cat_cars: 60_000, cat_attire: 80_000, cat_planners: 400_000,
  cat_beauty: 50_000, cat_decor: 150_000, cat_print: 20_000,
}

const FLEXIBLE_RULES: RefundRule[] = [
  { hours_before: 168, refund_percent: 100 },
  { hours_before: 48, refund_percent: 50 },
  { hours_before: 0, refund_percent: 0 },
]

const STRICT_RULES: RefundRule[] = [
  { hours_before: 720, refund_percent: 50 },
  { hours_before: 0, refund_percent: 0 },
]

export const mockPolicies: CancellationPolicy[] = [
  {
    id: 'pol_flex', name: 'مرنة', is_default: true, is_active: true,
    description: 'استرداد كامل قبل 7 أيام من الموعد، ونصف المبلغ قبل 48 ساعة.',
    rules: FLEXIBLE_RULES,
  },
  {
    id: 'pol_mid', name: 'متوسطة', is_default: false, is_active: true,
    description: 'استرداد كامل قبل 14 يوماً، و50% قبل 7 أيام، و25% قبل 72 ساعة.',
    rules: [
      { hours_before: 336, refund_percent: 100 },
      { hours_before: 168, refund_percent: 50 },
      { hours_before: 72, refund_percent: 25 },
      { hours_before: 0, refund_percent: 0 },
    ],
  },
  {
    id: 'pol_strict', name: 'صارمة', is_default: false, is_active: true,
    description: 'استرداد 50% فقط قبل 30 يوماً، ولا استرداد بعدها — للقاعات والمواسم.',
    rules: STRICT_RULES,
  },
]

// ---------------------------------------------------------------------------
// المستخدمون
// ---------------------------------------------------------------------------

const FIRST_NAMES = [
  'أحمد', 'محمد', 'عبدالله', 'خالد', 'يوسف', 'عمر', 'صالح', 'عبدالرحمن',
  'فاطمة', 'مريم', 'نورة', 'سارة', 'هدى', 'أسماء', 'ريم', 'بلقيس',
]

const LAST_NAMES = [
  'الحضرمي', 'الصنعاني', 'العديني', 'التعزي', 'الحديدي', 'المقطري',
  'باسلامة', 'الشرعبي', 'الأهدل', 'الوصابي',
]

function weightedUserStatus(): UserStatus {
  const roll = rng()
  if (roll > 0.94) return 'suspended'
  if (roll > 0.86) return 'pending'
  return 'active'
}

export const mockUsers: AppUser[] = Array.from({ length: 90 }, (_, i) => {
  const status = weightedUserStatus()
  const createdDaysAgo = intBetween(0, 300)
  return {
    id: `usr_${i + 1}`,
    full_name: `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`,
    email: `user${(i + 1).toString().padStart(4, '0')}@example.com`,
    phone: `+9677${intBetween(10_000_000, 79_999_999)}`,
    platform: (rng() > 0.4 ? 'android' : 'ios') as Platform,
    governorate: pick(ACTIVE_GOVERNORATES),
    status,
    app_version: pick(['1.4.0', '1.3.2', '1.3.0', '1.2.1']),
    sessions_count: status === 'pending' ? 0 : intBetween(5, 265),
    created_at: isoAt(createdDaysAgo, intBetween(7, 22)),
    last_seen_at: status === 'pending' ? null : isoAt(intBetween(0, 14), intBetween(7, 22)),
  }
}).sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

export const mockUserSessions: UserSession[] = mockUsers
  .filter((u) => u.status !== 'pending')
  .flatMap((user, i) =>
    Array.from({ length: intBetween(3, 8) }, (_, s) => ({
      id: `ses_${i}_${s}`,
      user_id: user.id,
      started_at: isoAt(s * 2 + intBetween(0, 1), intBetween(7, 23)),
      duration_seconds: intBetween(120, 2600),
      platform: user.platform,
      app_version: user.app_version,
      governorate: user.governorate,
    })),
  )

const IOS_DEVICES = ['iPhone 13', 'iPhone 12', 'iPhone 11', 'iPhone SE']
const ANDROID_DEVICES = ['Samsung Galaxy A54', 'Redmi Note 12', 'Infinix Hot 30', 'Tecno Spark 10']

export const mockUserDevices: UserDevice[] = mockUsers
  .filter((u) => u.status !== 'pending')
  .flatMap((user, i) =>
    Array.from({ length: rng() > 0.7 ? 2 : 1 }, (_, d) => ({
      id: `dev_${i}_${d}`,
      user_id: user.id,
      model: user.platform === 'ios' ? pick(IOS_DEVICES) : pick(ANDROID_DEVICES),
      os_version: user.platform === 'ios' ? '17.4' : '13',
      platform: user.platform,
      push_enabled: rng() > 0.18,
      last_used_at: user.last_seen_at ?? user.created_at,
    })),
  )

// ---------------------------------------------------------------------------
// مقدّمو الخدمة
// ---------------------------------------------------------------------------

const PROVIDER_FIRST = ['سعد', 'ماجد', 'فهد', 'بدر', 'ريان', 'هند', 'لمياء', 'غادة', 'منى', 'وليد']
const PROVIDER_LAST = ['باعوم', 'الحبيشي', 'الرداعي', 'السقاف', 'الجنيد', 'المخلافي', 'بن شملان']
const BUSINESS_NAME = ['اللؤلؤة', 'الأصالة', 'النخبة', 'الياسمين', 'بلقيس', 'السعادة', 'الفردوس', 'التاج']

/**
 * صدر الاسم التجاري تابع لقسم مقدّم الخدمة.
 *
 * «قاعة التاج» التي تبيع خدمات طباعة تبدو بياناتٍ مولَّدة لا سوقاً حقيقية،
 * ويُفقد الثقة بالشاشة كلها قبل أن يُقرأ رقم واحد فيها.
 */
const PREFIX_BY_CATEGORY: Record<string, string> = {
  halls: 'قاعة',
  catering: 'مطابخ',
  photography: 'استوديو',
  attire: 'معرض',
  beauty: 'صالون',
  artists: 'فرقة',
  sound: 'مركز',
  cars: 'معرض',
  planners: 'مؤسسة',
  printing: 'مطبعة',
  support: 'مؤسسة',
  decor: 'مركز',
}

function providerStatus(i: number): ProviderStatus {
  if (i % 12 === 0) return 'rejected'
  if (i % 7 === 0) return 'pending'
  if (i % 19 === 0) return 'suspended'
  return 'verified'
}

export const mockProviders: ServiceProvider[] = Array.from({ length: 44 }, (_, idx) => {
  const i = idx + 1
  const status = providerStatus(i)
  const trading = status === 'verified' || status === 'suspended'
  const appliedDaysAgo = intBetween(5, 380)
  const category = mockCategories[idx % mockCategories.length]
  const governorate = ACTIVE_GOVERNORATES[idx % ACTIVE_GOVERNORATES.length]

  return {
    id: `prv_${i}`,
    full_name: `${pick(PROVIDER_FIRST)} ${pick(PROVIDER_LAST)}`,
    business_name: `${PREFIX_BY_CATEGORY[category.slug] ?? 'مؤسسة'} ${pick(BUSINESS_NAME)}`,
    email: `provider${i.toString().padStart(3, '0')}@example.com`,
    phone: `+9677${intBetween(70_000_000, 79_999_999)}`,
    bio: `خبرة تتجاوز ${intBetween(3, 15)} سنوات في تجهيز الأعراس.`,
    governorate,
    coverage_areas: [governorate],
    status,
    is_featured: i % 13 === 0,
    rating: trading ? Math.round(between(3.5, 5) * 10) / 10 : 0,
    reviews_count: trading ? intBetween(3, 80) : 0,
    completed_bookings: trading ? intBetween(5, 160) : 0,
    total_earnings: trading ? intBetween(150_000, 7_000_000) : 0,
    // معظمهم على العمولة العامة؛ القليل باتفاق خاص
    commission_percent: i % 9 === 0 ? pick([7, 8, 12, 15]) : null,
    rejection_reason: status === 'rejected' ? 'السجل التجاري منتهي الصلاحية.' : '',
    categories: [category.name],
    applied_at: isoAt(appliedDaysAgo, intBetween(8, 20)),
    verified_at: trading ? isoAt(Math.max(0, appliedDaysAgo - 4), intBetween(8, 20)) : null,
  }
}).sort((a, b) => new Date(b.applied_at).getTime() - new Date(a.applied_at).getTime())

/** يربط كل مقدّم خدمة بقسمه، للبحث والتصفية. */
const providerCategoryId = new Map<string, string>()
for (const provider of mockProviders) {
  const category = mockCategories.find((c) => c.name === provider.categories[0])
  if (category) providerCategoryId.set(provider.id, category.id)
}

const DOCUMENT_TYPES: DocumentType[] = ['id_card', 'commercial_register', 'work_samples']

export const mockDocuments: ProviderDocument[] = mockProviders.flatMap((provider, i) =>
  DOCUMENT_TYPES.map((type, d) => {
    const status: DocumentStatus =
      provider.status === 'pending'
        ? 'pending'
        : provider.status === 'rejected' && type === 'commercial_register'
          ? 'rejected'
          : 'approved'
    return {
      id: `doc_${i}_${d}`,
      provider_id: provider.id,
      type,
      file_name: `${type}-${provider.id}.pdf`,
      status,
      note: status === 'rejected' ? 'السجل التجاري منتهي الصلاحية.' : '',
      uploaded_at: provider.applied_at,
    }
  }),
)

const PACKAGE_TIERS = ['باقة أساسية', 'باقة متوسطة', 'باقة شاملة']

export const mockServices: ProviderService[] = mockProviders
  .filter((p) => p.status === 'verified' || p.status === 'suspended')
  .flatMap((provider, i) => {
    const categoryId = providerCategoryId.get(provider.id)!
    const category = mockCategories.find((c) => c.id === categoryId)!
    const base = CATEGORY_BASE_PRICE[categoryId]
    // القاعات تأخذ السياسة الصارمة لارتباطها بموسم وموعد لا يُعوَّض
    const policy = categoryId === 'cat_halls' ? mockPolicies[2] : mockPolicies[0]

    return PACKAGE_TIERS.map((tier, t) => ({
      id: `svc_${i}_${t}`,
      provider_id: provider.id,
      provider_name: provider.business_name,
      category_id: categoryId,
      category_name: category.name,
      title: `${category.name} — ${tier}`,
      description: 'تشمل الباقة تجهيزاً كاملاً مع فريق مختص وضمان جودة التنفيذ.',
      price: base * (t + 1),
      price_to: base * (t + 1) + base / 2,
      unit: categoryId === 'cat_print' ? 'لكل 100 بطاقة' : categoryId === 'cat_cars' ? 'لليوم' : 'للحجز',
      deposit_percent: [20, 30, 50][t],
      duration_minutes: [120, 240, 480][t],
      cancellation_policy_id: policy.id,
      cancellation_policy_name: policy.name,
      is_active: provider.status === 'verified',
    }))
  })

// ---------------------------------------------------------------------------
// خطط الأعراس والحجوزات
// ---------------------------------------------------------------------------

const bookableServices = mockServices.filter((s) => s.is_active)

/**
 * الخدمات المتاحة مجمَّعة حسب القسم.
 *
 * العرس يحجز قاعة ومصوّراً وفرقة — لا ثلاث باقات من القاعة نفسها. الاختيار من
 * أقسام مختلفة هو ما يجعل تضارب المواعيد، حين يقع، تضارباً حقيقياً بين عرسين
 * على مقدّم الخدمة نفسه لا مجرّد باقات متجاورة لعرس واحد.
 */
const servicesByCategory = [...new Set(bookableServices.map((s) => s.category_name))].map(
  (name) => bookableServices.filter((s) => s.category_name === name),
)

interface PlanDraft extends Omit<WeddingPlan, 'services_count' | 'total_cost' | 'paid_amount' | 'remaining_amount'> {}

const planDrafts: PlanDraft[] = mockUsers
  .filter((u) => u.status === 'active')
  .slice(0, 26)
  .map((user, i) => {
    // بعض الأعراس مضت وبعضها قادم، فتظهر كل الحالات على الشاشة
    const offset = intBetween(-45, 110)
    const weddingDate = isoDay(-offset)
    const past = offset < 0
    const status: PlanStatus = past
      ? 'completed'
      : rng() > 0.9
        ? 'cancelled'
        : rng() > 0.55
          ? 'confirmed'
          : 'planning'

    return {
      id: `pln_${i + 1}`,
      user_id: user.id,
      user_name: user.full_name,
      title: `عرس ${user.full_name.split(' ')[0]}`,
      wedding_date: weddingDate,
      governorate: user.governorate,
      guests_count: intBetween(150, 800),
      budget: intBetween(30, 200) * 50_000,
      status,
      notes: 'تجهيز العرس بالكامل عبر المنصة.',
      created_at: isoAt(intBetween(10, 120), intBetween(9, 21)),
    }
  })

function bookingStatusFor(planPast: boolean, i: number): BookingStatus {
  if (i % 13 === 0) return 'rejected'
  if (i % 11 === 0) return 'cancelled'
  // A booking still awaiting a reply after the wedding has passed is not
  // "pending" — the response window closed on it.
  if (i % 5 === 0) return planPast ? 'expired' : 'pending_provider'
  return planPast ? 'completed' : 'confirmed'
}

const DISTRICTS = ['السنينة', 'حدة', 'الصافية', 'المعلا', 'الكمب', 'القاهرة', 'الروضة']

let bookingSeq = 0

const planBookings: Booking[] = planDrafts.flatMap((plan, planIndex) => {
  const planPast = new Date(plan.wedding_date) < new Date()

  return Array.from({ length: intBetween(1, 4) }, (_, n) => {
    // قسم مختلف لكل خدمة في العرس الواحد، وباقة واحدة من داخله.
    const pool = servicesByCategory[(planIndex + n) % servicesByCategory.length]
    const service = pool[(planIndex * 7 + n * 3) % pool.length]
    const provider = mockProviders.find((p) => p.id === service.provider_id)!
    const status = bookingStatusFor(planPast, planIndex + n)
    const settled = status === 'confirmed' || status === 'completed'

    const total = service.price
    const deposit = Math.round((total * service.deposit_percent) / 100)
    const commissionPercent = provider.commission_percent ?? 10
    const paid = settled ? total : deposit
    // The provider's own failure to serve returns everything; the customer's
    // change of mind returns what the cancellation ladder allows.
    const refunded =
      status === 'rejected' || status === 'expired'
        ? deposit
        : status === 'cancelled'
          ? Math.round(deposit / 2)
          : 0

    bookingSeq += 1

    return {
      id: `bkg_${bookingSeq}`,
      reference: `BK-2026-${bookingSeq.toString().padStart(6, '0')}`,
      user_id: plan.user_id,
      user_name: plan.user_name,
      provider_id: provider.id,
      provider_name: provider.business_name,
      service_id: service.id,
      service_title: service.title,
      category_id: service.category_id,
      category_name: service.category_name,
      plan_id: plan.id,
      event_date: plan.wedding_date,
      event_time: pick(['16:00', '18:00', '20:00', '21:30']),
      governorate: plan.governorate,
      address: `حي ${pick(DISTRICTS)} — شارع ${intBetween(10, 60)}`,
      guests_count: plan.guests_count,
      notes: 'يرجى التواجد قبل الموعد بساعة.',
      status,
      total_price: total,
      deposit_amount: deposit,
      paid_amount: paid,
      refunded_amount: refunded,
      commission_percent: commissionPercent,
      commission_amount: settled ? Math.round((total * commissionPercent) / 100) : 0,
      cancellation_rules: service.cancellation_policy_id === 'pol_strict' ? STRICT_RULES : FLEXIBLE_RULES,
      rejection_reason:
        status === 'rejected'
          ? 'الموعد محجوز مسبقاً لدينا.'
          : status === 'expired'
            ? 'انتهت مهلة رد مقدّم الخدمة.'
            : '',
      cancel_reason: status === 'cancelled' ? 'ألغى العميل بعد تغيير موعد العرس.' : '',
      created_at: plan.created_at,
      confirmed_at: settled ? isoAt(intBetween(5, 100), 11) : null,
      completed_at: status === 'completed' ? `${plan.wedding_date}T21:00:00.000Z` : null,
      cancelled_at:
        status === 'cancelled' || status === 'rejected' || status === 'expired'
          ? isoAt(intBetween(3, 90), 13)
          : null,
    }
  })
})

/**
 * طلبات مزدوجة على مقدّم الخدمة نفسه.
 *
 * القاعة المطلوبة يطلبها عرسان في الليلة ذاتها: الأول مؤكد والثاني ما زال
 * ينتظر الرد. هذه هي الحالة التي يوجد «مراقب تضارب المواعيد» من أجلها، ولا
 * تُولّدها التوزيعة العشوائية وحدها، فتُضاف صراحةً.
 */
const doubleRequests: Booking[] = planDrafts
  .filter((plan) => new Date(plan.wedding_date) > new Date() && plan.status !== 'cancelled')
  // أقرب الأعراس أولاً، فالتضارب المعروض يقع ضمن ما يراه المسؤول الآن لا بعد أشهر.
  .sort((a, b) => a.wedding_date.localeCompare(b.wedding_date))
  .slice(0, 3)
  .flatMap((plan, i) => {
    // مورد مختلف لكل حالة، وإلا بدت الشاشة وكأنها تكرّر التنبيه نفسه ثلاثاً.
    const candidates = planBookings.filter(
      (booking) =>
        booking.status === 'confirmed' &&
        booking.event_date !== plan.wedding_date &&
        booking.plan_id !== plan.id,
    )
    const taken = candidates[(i * 11) % Math.max(1, candidates.length)]
    if (!taken) return []

    bookingSeq += 1
    return [
      {
        ...taken,
        id: `bkg_${bookingSeq}`,
        reference: `BK-2026-${bookingSeq.toString().padStart(6, '0')}`,
        user_id: plan.user_id,
        user_name: plan.user_name,
        plan_id: plan.id,
        // نفس مقدّم الخدمة ونفس الساعة، في يوم عرس هذا العميل.
        event_date: plan.wedding_date,
        event_time: taken.event_time,
        governorate: plan.governorate,
        guests_count: plan.guests_count,
        status: 'pending_provider' as const,
        paid_amount: taken.deposit_amount,
        refunded_amount: 0,
        commission_amount: 0,
        confirmed_at: null,
        completed_at: null,
        cancelled_at: null,
        created_at: isoAt(intBetween(1, 12), 10 + i),
      },
    ]
  })

/** الحجز الآخر في اليوم نفسه لدى المزوّد نفسه — يصنع التضارب المعروض. */
const contested: Booking[] = doubleRequests.map((request) => {
  bookingSeq += 1
  const host = planDrafts.find((plan) => plan.wedding_date === request.event_date)
  return {
    ...request,
    id: `bkg_${bookingSeq}`,
    reference: `BK-2026-${bookingSeq.toString().padStart(6, '0')}`,
    user_id: host?.user_id ?? request.user_id,
    user_name: host?.user_name ?? request.user_name,
    plan_id: host?.id ?? null,
    status: 'confirmed' as const,
    paid_amount: request.total_price,
    commission_amount: Math.round((request.total_price * request.commission_percent) / 100),
    confirmed_at: isoAt(intBetween(14, 40), 12),
  }
})

export const mockBookings: Booking[] = [...planBookings, ...doubleRequests, ...contested]

/** المجاميع تُحسب من الحجوزات، لا تُخزَّن — فلا تتباعد الأرقام أبداً. */
export const mockPlans: WeddingPlan[] = planDrafts.map((plan) => {
  const items = mockBookings.filter(
    (b) =>
      b.plan_id === plan.id &&
      b.status !== 'cancelled' &&
      b.status !== 'rejected' &&
      b.status !== 'expired',
  )
  const totalCost = items.reduce((sum, b) => sum + b.total_price, 0)
  const paid = items.reduce((sum, b) => sum + b.paid_amount, 0)
  return {
    ...plan,
    services_count: items.length,
    total_cost: totalCost,
    paid_amount: paid,
    remaining_amount: totalCost - paid,
  }
})

// ---------------------------------------------------------------------------
// المالية
// ---------------------------------------------------------------------------

const PAYMENT_METHODS: PaymentMethod[] = ['jawali', 'cash_wallet', 'kuraimi', 'bank_transfer', 'card']

let paymentSeq = 0
const nextPaymentRef = () => `TRX-2026-${(++paymentSeq).toString().padStart(6, '0')}`

export const mockPayments: Payment[] = mockBookings.flatMap((booking) => {
  const method = pick(PAYMENT_METHODS)
  const refunded = booking.status === 'rejected' || booking.status === 'cancelled'
  const commission = booking.commission_percent

  const deposit: Payment = {
    id: `pay_dep_${booking.id}`,
    reference: nextPaymentRef(),
    user_id: booking.user_id,
    user_name: booking.user_name,
    provider_id: booking.provider_id,
    provider_name: booking.provider_name,
    booking_id: booking.id,
    booking_reference: booking.reference,
    kind: 'deposit',
    description: `عربون حجز — ${booking.category_name}`,
    amount: booking.deposit_amount,
    platform_share: Math.round((booking.deposit_amount * commission) / 100),
    net_amount: booking.deposit_amount - Math.round((booking.deposit_amount * commission) / 100),
    method,
    status: (refunded ? 'refunded' : 'paid') as PaymentStatus,
    gateway_ref: `gw_${booking.id}`,
    created_at: booking.created_at,
    refunded_at: refunded ? booking.cancelled_at : null,
  }

  if (booking.status !== 'confirmed' && booking.status !== 'completed') return [deposit]

  const balanceAmount = booking.total_price - booking.deposit_amount
  const balance: Payment = {
    ...deposit,
    id: `pay_bal_${booking.id}`,
    reference: nextPaymentRef(),
    kind: 'balance',
    description: `سداد المتبقي — ${booking.category_name}`,
    amount: balanceAmount,
    platform_share: Math.round((balanceAmount * commission) / 100),
    net_amount: balanceAmount - Math.round((balanceAmount * commission) / 100),
    status: 'paid',
    gateway_ref: `gw_${booking.id}_b`,
    created_at: booking.confirmed_at ?? booking.created_at,
    refunded_at: null,
  }

  return [deposit, balance]
}).sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

const settlementProviders = [
  ...new Set(mockBookings.filter((b) => b.status === 'completed').map((b) => b.provider_id)),
]

export const mockSettlements: Settlement[] = settlementProviders.map((providerId, i) => {
  const provider = mockProviders.find((p) => p.id === providerId)!
  const items = mockBookings.filter((b) => b.provider_id === providerId && b.status === 'completed')
  const gross = items.reduce((sum, b) => sum + b.paid_amount, 0)
  const commission = items.reduce((sum, b) => sum + b.commission_amount, 0)
  const status = (['pending', 'approved', 'paid'] as const)[i % 3]

  const periodEnd = new Date()
  periodEnd.setDate(0)
  const periodStart = new Date(periodEnd)
  periodStart.setDate(1)

  return {
    id: `stl_${i + 1}`,
    reference: `STL-2026-${(i + 1).toString().padStart(4, '0')}`,
    provider_id: providerId,
    provider_name: provider.business_name,
    period_start: periodStart.toISOString().slice(0, 10),
    period_end: periodEnd.toISOString().slice(0, 10),
    gross_amount: gross,
    commission_amount: commission,
    net_amount: gross - commission,
    status,
    method: 'تحويل بنكي',
    note: '',
    created_at: isoAt(intBetween(1, 20), 10),
    paid_at: status === 'paid' ? isoAt(intBetween(0, 5), 12) : null,
    bookings_count: items.length,
  }
})

// ---------------------------------------------------------------------------
// الثقة
// ---------------------------------------------------------------------------

const REVIEW_COMMENTS = [
  'خدمة ممتازة والتزام تام بالموعد، شكراً لكم.',
  'التنفيذ كان جيداً لكن التأخير في البداية أزعجنا.',
  'أنصح بهم بشدة، الجودة تستحق السعر.',
  'تعامل راقٍ وتنسيق جميل، وفّقكم الله.',
  'كل شيء تم كما اتفقنا تماماً.',
]

export const mockReviews: Review[] = mockBookings
  .filter((b) => b.status === 'completed')
  .map((booking, i) => ({
    id: `rev_${i + 1}`,
    booking_id: booking.id,
    booking_reference: booking.reference,
    user_id: booking.user_id,
    user_name: booking.user_name,
    provider_id: booking.provider_id,
    provider_name: booking.provider_name,
    rating: intBetween(3, 5),
    comment: pick(REVIEW_COMMENTS),
    // بعضها مُبلَّغ عنه لتظهر شاشة المراجعة بعمل فعلي
    status: i % 9 === 0 ? 'flagged' : i % 17 === 0 ? 'hidden' : 'published',
    hidden_reason: i % 17 === 0 ? 'لغة غير لائقة.' : '',
    created_at: booking.completed_at ?? booking.created_at,
  }))

const DISPUTE_SUBJECTS = [
  'مقدم الخدمة لم يحضر في الموعد',
  'جودة التنفيذ أقل من المتفق عليه',
  'خُصم مبلغ إضافي دون اتفاق',
  'العميل ألغى في اللحظة الأخيرة',
  'خلاف على تفاصيل الباقة',
]

const DISPUTE_STATUSES: DisputeStatus[] = ['open', 'investigating', 'resolved', 'closed']

export const mockDisputes: Dispute[] = mockBookings
  .filter((_, i) => i % 9 === 0)
  .map((booking, i) => {
    const status = DISPUTE_STATUSES[i % 4]
    const settled = status === 'resolved' || status === 'closed'
    return {
      id: `dsp_${i + 1}`,
      reference: `DSP-2026-${(i + 1).toString().padStart(4, '0')}`,
      booking_id: booking.id,
      booking_reference: booking.reference,
      opened_by: (i % 4 === 0 ? 'provider' : 'customer') as 'customer' | 'provider',
      user_id: booking.user_id,
      user_name: booking.user_name,
      provider_id: booking.provider_id,
      provider_name: booking.provider_name,
      subject: DISPUTE_SUBJECTS[i % DISPUTE_SUBJECTS.length],
      description: 'تفاصيل الشكوى مرفقة مع المحادثات والإيصالات.',
      category: (['no_show', 'quality', 'payment', 'cancellation', 'behaviour'] as const)[i % 5],
      status,
      resolution: settled ? 'تمت التسوية باتفاق الطرفين بعد مراجعة الإدارة.' : '',
      refund_amount: status === 'resolved' ? Math.round(booking.paid_amount * 0.3) : 0,
      resolved_by: settled ? 'admin@example.com' : '',
      created_at: isoAt(intBetween(2, 40), 11),
      resolved_at: settled ? isoAt(intBetween(0, 10), 15) : null,
    }
  })

export const mockDisputeMessages: DisputeMessage[] = mockDisputes.flatMap((dispute, i) => {
  const opening: DisputeMessage = {
    id: `dmsg_${i}_0`,
    dispute_id: dispute.id,
    author: dispute.opened_by,
    author_name: dispute.opened_by === 'customer' ? dispute.user_name : dispute.provider_name,
    body: 'السلام عليكم، أرجو النظر في المشكلة المذكورة وإفادتي.',
    created_at: dispute.created_at,
  }
  if (dispute.status === 'open') return [opening]

  return [
    opening,
    {
      id: `dmsg_${i}_1`,
      dispute_id: dispute.id,
      author: 'admin' as const,
      author_name: 'فريق المنصة',
      body: 'شكراً لتواصلك، تم فتح النزاع ونحن نتواصل مع الطرف الآخر.',
      created_at: dispute.resolved_at ?? dispute.created_at,
    },
  ]
})

// ---------------------------------------------------------------------------
// الدخل
// ---------------------------------------------------------------------------

export const mockSubscriptionPlans: SubscriptionPlan[] = [
  {
    id: 'sub_basic', name: 'الباقة الأساسية', price: 0, duration_days: 30, is_active: true,
    description: 'ظهور عادي وحتى 5 خدمات معروضة.',
    perks: ['حتى 5 خدمات', 'ملف تعريفي أساسي'],
    subscribers_count: 18,
  },
  {
    id: 'sub_silver', name: 'الباقة الفضية', price: 15_000, duration_days: 30, is_active: true,
    description: 'خدمات غير محدودة وأولوية في نتائج البحث.',
    perks: ['خدمات غير محدودة', 'أولوية في البحث', 'شارة نشط'],
    subscribers_count: 11,
  },
  {
    id: 'sub_gold', name: 'الباقة الذهبية', price: 40_000, duration_days: 30, is_active: true,
    description: 'ظهور مميز في الصفحة الرئيسية وتقارير أداء شهرية.',
    perks: ['كل مزايا الفضية', 'ظهور مميز في الرئيسية', 'تقارير أداء', 'دعم مخصص'],
    subscribers_count: 6,
  },
]

export const mockPromotions: Promotion[] = mockProviders
  .filter((p) => p.status === 'verified')
  .filter((_, i) => i % 3 === 0)
  .map((provider, i) => ({
    id: `promo_${i + 1}`,
    provider_id: provider.id,
    provider_name: provider.business_name,
    kind: (['featured', 'banner', 'category_top'] as const)[i % 3],
    placement: (['الصفحة الرئيسية', 'نتائج البحث', 'صفحة القسم'] as const)[i % 3],
    category_name: provider.categories[0],
    amount: [25_000, 50_000, 80_000][i % 3],
    status: i % 5 === 0 ? 'ended' : 'active',
    impressions: intBetween(1200, 19_000),
    clicks: intBetween(40, 900),
    starts_at: isoAt(15, 9),
    ends_at: isoAt(-15, 9),
  }))

// ---------------------------------------------------------------------------
// التشغيل
// ---------------------------------------------------------------------------

export const mockNotifications: PushNotification[] = [
  {
    id: 'ntf_1', title: 'موسم الأعراس بدأ 🎉',
    body: 'احجز قاعتك مبكراً واحصل على خصم 10% حتى نهاية الشهر.',
    audience: 'customers', status: 'sent', scheduled_at: null, sent_at: isoAt(2, 19),
    recipients: 14_200, opened: 6180,
  },
  {
    id: 'ntf_2', title: 'وثّق حسابك الآن',
    body: 'أكمل رفع مستنداتك لتبدأ استقبال الحجوزات.',
    audience: 'providers', status: 'sent', scheduled_at: null, sent_at: isoAt(6, 11),
    recipients: 320, opened: 210,
  },
  {
    id: 'ntf_3', title: 'تذكير بموعد عرسك',
    body: 'بقي أسبوع على موعدك — راجع خطة العرس وتأكد من الحجوزات.',
    audience: 'active', status: 'scheduled', scheduled_at: isoAt(-3, 18), sent_at: null,
    recipients: 2400, opened: 0,
  },
  {
    id: 'ntf_4', title: 'صيانة مجدولة',
    body: 'سيتوقف التطبيق مؤقتاً ليلة الجمعة من 2 إلى 4 فجراً.',
    audience: 'all', status: 'draft', scheduled_at: null, sent_at: null,
    recipients: 0, opened: 0,
  },
  {
    id: 'ntf_5', title: 'تنبيه أمني',
    body: 'يُنصح بتفعيل التحقق بخطوتين من الإعدادات.',
    audience: 'all', status: 'failed', scheduled_at: null, sent_at: isoAt(12, 9),
    recipients: 0, opened: 0,
  },
]

export const mockVersions: AppVersion[] = [
  {
    id: 'ver_1', platform: 'ios', version: '1.4.0', build: 1401, released_at: isoAt(5, 10),
    force_update: false, rollout_percent: 100,
    notes: 'إضافة خطة العرس وتحسين سرعة البحث.',
  },
  {
    id: 'ver_2', platform: 'android', version: '1.4.0', build: 1402, released_at: isoAt(4, 10),
    force_update: false, rollout_percent: 70,
    notes: 'إضافة خطة العرس ودعم محفظة جوالي.',
  },
  {
    id: 'ver_3', platform: 'ios', version: '1.3.2', build: 1322, released_at: isoAt(30, 10),
    force_update: true, rollout_percent: 100,
    notes: 'إصلاح ثغرة في تجديد الجلسة — التحديث إجباري.',
  },
  {
    id: 'ver_4', platform: 'android', version: '1.3.0', build: 1300, released_at: isoAt(48, 10),
    force_update: false, rollout_percent: 100,
    notes: 'إشعارات الحجز داخل التطبيق.',
  },
]

/**
 * التثبيتات اليومية حسب المنصة — اتجاه صاعد مع ارتفاع في نهاية الأسبوع اليمنية
 * (الخميس والجمعة)، حيث تُقام معظم الأعراس.
 */
export const mockInstallsByDay: DailyBreakdown[] = Array.from({ length: HISTORY_DAYS }, (_, i) => {
  const daysAgo = HISTORY_DAYS - 1 - i
  const date = isoDay(daysAgo)
  const weekday = new Date(date).getDay()
  const weekendLift = weekday === 4 || weekday === 5 ? 1.18 : 1
  const total = Math.round((120 + i * 1.6) * weekendLift * between(0.86, 1.14))
  const android = Math.round(total * between(0.58, 0.66))
  return { date, ios: total - android, android }
})

export const mockBookingsByDay: MetricPoint[] = mockInstallsByDay.map((day) => ({
  date: day.date,
  value: Math.max(1, Math.round((day.ios + day.android) * between(0.1, 0.2))),
}))

export const mockRevenueByDay: MetricPoint[] = mockBookingsByDay.map((point) => ({
  date: point.date,
  value: Math.round(point.value * between(180_000, 340_000)),
}))

export const mockActiveByDay: MetricPoint[] = mockInstallsByDay.map((day, i) => ({
  date: day.date,
  value: Math.round((day.ios + day.android) * (3.2 + 0.4 * Math.sin(i * 1.7))),
}))

export const mockSettings: AppSettings = {
  maintenance_mode: false,
  maintenance_message: 'نقوم بأعمال صيانة سريعة، عُد إلينا خلال ساعة.',
  allow_signups: true,
  allow_provider_signups: true,
  commission_percent: 10,
  default_deposit_percent: 30,
  currency: 'YER',
  min_ios_version: '1.3.2',
  min_android_version: '1.3.0',
  support_email: 'support@example.com',
  support_phone: '+967700000000',
  default_locale: 'ar',
}

export const mockAdmins: AdminAccount[] = [
  { user_id: 'demo-admin', email: 'admin@example.com', role: 'owner', created_at: isoAt(200, 9) },
  { user_id: 'adm_2', email: 'ops@example.com', role: 'admin', created_at: isoAt(90, 11) },
  { user_id: 'adm_3', email: 'analyst@example.com', role: 'viewer', created_at: isoAt(30, 14) },
]
