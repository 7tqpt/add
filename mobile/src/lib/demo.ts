import type {
  Booking,
  Governorate,
  Service,
  ServiceCategory,
  SupportMessage,
  SupportTicket,
  WeddingPlan,
} from './types'

/**
 * بيانات تجريبية تعمل بلا خادم.
 *
 * الغرض نفسه الذي في اللوحة: التطبيق يُتصفَّح كاملاً قبل أن يُربط بمشروع
 * Supabase — يراه صاحب المنصة على جواله في دقيقة، وتُراجَع الشاشات دون انتظار
 * شبكة. تُستبدل كلها بالبيانات الحقيقية بمجرد وجود المفتاحين في ‎.env‎.
 */

const day = (offset: number) => {
  const d = new Date()
  d.setDate(d.getDate() + offset)
  return d.toISOString().slice(0, 10)
}
const at = (hoursAgo: number) => new Date(Date.now() - hoursAgo * 3_600_000).toISOString()

export const demoGovernorates: Governorate[] = [
  { id: 'g1', name: 'أمانة العاصمة' },
  { id: 'g2', name: 'عدن' },
  { id: 'g3', name: 'تعز' },
  { id: 'g4', name: 'الحديدة' },
  { id: 'g5', name: 'حضرموت' },
  { id: 'g6', name: 'إب' },
]

export const demoCategories: ServiceCategory[] = [
  { id: 'c1', name: 'القاعات والخيام', slug: 'halls', description: '', sort_order: 1 },
  { id: 'c2', name: 'الطبخ والضيافة', slug: 'catering', description: '', sort_order: 2 },
  { id: 'c3', name: 'التصوير والإضاءة', slug: 'photography', description: '', sort_order: 3 },
  { id: 'c4', name: 'الديكور والكوشة', slug: 'decor', description: '', sort_order: 4 },
  { id: 'c5', name: 'الصوت والمعدات', slug: 'sound', description: '', sort_order: 5 },
]

function service(
  id: string,
  title: string,
  provider: string,
  categoryIndex: number,
  price: number,
  extra: Partial<Service> = {},
): Service {
  const category = demoCategories[categoryIndex]
  return {
    id,
    provider_id: `p${id}`,
    provider_name: provider,
    provider_governorate: 'أمانة العاصمة',
    provider_rating: 4.6,
    provider_reviews_count: 24,
    provider_is_featured: false,
    category_id: category.id,
    category_name: category.name,
    category_slug: category.slug,
    title,
    description:
      'خدمة كاملة تشمل التجهيز والتنسيق مع بقية مقدّمي الخدمة في يوم العرس، مع فريق متكامل.',
    price,
    price_to: null,
    unit: 'للحجز',
    deposit_percent: 30,
    duration_minutes: 300,
    images: [],
    attributes: {},
    cancellation_policy_name: 'مرنة',
    ...extra,
  }
}

export const demoServices: Service[] = [
  service('s1', 'قاعة التاج — باقة شاملة', 'قاعة التاج', 0, 850_000, {
    provider_is_featured: true,
    provider_rating: 4.9,
    provider_reviews_count: 87,
    price_to: 1_400_000,
  }),
  service('s2', 'مندي وحنيذ لـ300 شخص', 'مطبخ الأصالة', 1, 420_000, {
    provider_rating: 4.7,
    provider_reviews_count: 52,
  }),
  service('s3', 'تصوير فيديو وفوتوغرافي', 'استوديو السعادة', 2, 180_000, {
    provider_governorate: 'عدن',
    provider_rating: 4.4,
  }),
  service('s4', 'كوشة ورد طبيعي', 'ديكور الياسمين', 3, 260_000, {
    provider_rating: 4.8,
    provider_reviews_count: 31,
  }),
  service('s5', 'صوتيات وإضاءة كاملة', 'مركز النجم', 4, 95_000, {
    provider_governorate: 'تعز',
    provider_rating: 4.2,
  }),
]

export const demoBookings: Booking[] = [
  {
    id: 'b1',
    reference: 'BK-2026-000318',
    user_id: 'u1',
    user_name: 'أحمد الشرعبي',
    provider_id: 'ps1',
    provider_name: 'قاعة التاج',
    service_id: 's1',
    service_title: 'قاعة التاج — باقة شاملة',
    category_name: 'القاعات والخيام',
    plan_id: 'pl1',
    event_date: day(28),
    event_time: '20:00',
    governorate: 'أمانة العاصمة',
    address: 'حي السنينة — صنعاء',
    guests_count: 400,
    notes: '',
    status: 'confirmed',
    total_price: 850_000,
    deposit_amount: 255_000,
    paid_amount: 255_000,
    refunded_amount: 0,
    created_at: at(72),
  },
  {
    id: 'b2',
    reference: 'BK-2026-000402',
    user_id: 'u1',
    user_name: 'أحمد الشرعبي',
    provider_id: 'ps2',
    provider_name: 'مطبخ الأصالة',
    service_id: 's2',
    service_title: 'مندي وحنيذ لـ300 شخص',
    category_name: 'الطبخ والضيافة',
    plan_id: 'pl1',
    event_date: day(28),
    event_time: '19:00',
    governorate: 'أمانة العاصمة',
    address: 'حي السنينة — صنعاء',
    guests_count: 300,
    notes: 'بدون بهارات حارّة',
    status: 'pending_provider',
    total_price: 420_000,
    deposit_amount: 126_000,
    paid_amount: 0,
    refunded_amount: 0,
    created_at: at(20),
  },
  {
    id: 'b3',
    reference: 'BK-2026-000155',
    user_id: 'u1',
    user_name: 'أحمد الشرعبي',
    provider_id: 'ps3',
    provider_name: 'استوديو السعادة',
    service_id: 's3',
    service_title: 'تصوير فيديو وفوتوغرافي',
    category_name: 'التصوير والإضاءة',
    plan_id: null,
    event_date: day(-40),
    event_time: '18:30',
    governorate: 'أمانة العاصمة',
    address: 'قاعة الأندلس',
    guests_count: 250,
    notes: '',
    status: 'completed',
    total_price: 180_000,
    deposit_amount: 54_000,
    paid_amount: 180_000,
    refunded_amount: 0,
    created_at: at(1400),
  },
]

export const demoPlans: WeddingPlan[] = [
  {
    id: 'pl1',
    title: 'عرس أحمد ومريم',
    wedding_date: day(28),
    governorate: 'أمانة العاصمة',
    guests_count: 400,
    budget: 2_000_000,
    status: 'planning',
    notes: '',
    services_count: 2,
    total_cost: 1_270_000,
    paid_amount: 255_000,
    remaining_amount: 1_015_000,
  },
]

export const demoTickets: SupportTicket[] = [
  {
    id: 't1',
    reference: 'SUP-2026-000118',
    subject: 'خُصم المبلغ ولم يظهر الحجز',
    category: 'payment',
    status: 'waiting_customer',
    created_at: at(30),
    last_message_at: at(4),
  },
]

export const demoTicketMessages: SupportMessage[] = [
  {
    id: 'tm1',
    ticket_id: 't1',
    author: 'customer',
    author_name: 'أحمد الشرعبي',
    body: 'حوّلت العربون من محفظتي وخُصم المبلغ، لكن الحجز ما زال يظهر «بانتظار الدفع».',
    created_at: at(30),
  },
  {
    id: 'tm2',
    ticket_id: 't1',
    author: 'admin',
    author_name: 'فريق خدمة العملاء',
    body: 'راجعنا سجل البوابة ووجدنا العملية معلّقة لديهم. سيُعاد المبلغ خلال ٤٨ ساعة أو يُثبَّت الحجز.',
    created_at: at(4),
  },
]

/** تأخير بسيط ليظهر مؤشّر التحميل كما سيظهر مع شبكة حقيقية. */
export function delay<T>(value: T, ms = 320): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms))
}
