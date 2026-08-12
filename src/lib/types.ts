// أنواع منصة حجوزات وتجهيز الأعراس — تطابق مخطط قاعدة البيانات في supabase/schema.sql

export type Platform = 'ios' | 'android'

/** One page of rows plus the unfiltered total, for pagination controls. */
export interface Paged<T> {
  rows: T[]
  total: number
}

// ---------------------------------------------------------------------------
// المرجعيات
// ---------------------------------------------------------------------------

export interface Governorate {
  id: string
  name: string
  sort_order: number
  is_active: boolean
}

/** حقل إضافي خاص بقسم — سعة القاعة، عدد أفراد الفرقة، تصوير بالدرون… */
export interface CategoryField {
  key: string
  label: string
  type: 'text' | 'number' | 'boolean'
  required: boolean
}

export interface ServiceCategory {
  id: string
  name: string
  slug: string
  description: string
  sort_order: number
  is_active: boolean
  custom_fields: CategoryField[]
  /** عدد مقدّمي الخدمة في هذا القسم — محسوب، لا مخزّن. */
  providers_count?: number
}

/** درجة في سلّم الاسترداد: كلما اقترب الموعد قلّت النسبة. */
export interface RefundRule {
  hours_before: number
  refund_percent: number
}

export interface CancellationPolicy {
  id: string
  name: string
  description: string
  rules: RefundRule[]
  is_default: boolean
  is_active: boolean
}

// ---------------------------------------------------------------------------
// الحسابات
// ---------------------------------------------------------------------------

export type UserStatus = 'active' | 'suspended' | 'pending'

export interface AppUser {
  id: string
  full_name: string
  email: string
  phone: string
  platform: Platform
  governorate: string
  status: UserStatus
  app_version: string
  sessions_count: number
  created_at: string
  last_seen_at: string | null
}

export interface UserSession {
  id: string
  user_id: string
  started_at: string
  duration_seconds: number
  platform: Platform
  app_version: string
  governorate: string
}

export interface UserDevice {
  id: string
  user_id: string
  model: string
  os_version: string
  platform: Platform
  push_enabled: boolean
  last_used_at: string
}

// ---------------------------------------------------------------------------
// مقدّمو الخدمة
// ---------------------------------------------------------------------------

/**
 * حالات حساب مقدّم الخدمة كما نصّت عليها وثيقة المشروع.
 * «مستخدم عادي» ليس حالة هنا — هو مستخدم بلا ملف مقدّم خدمة أصلاً.
 */
export type ProviderStatus = 'pending' | 'verified' | 'rejected' | 'suspended'

export interface ServiceProvider {
  id: string
  full_name: string
  business_name: string
  email: string
  phone: string
  bio: string
  governorate: string
  coverage_areas: string[]
  status: ProviderStatus
  is_featured: boolean
  rating: number
  reviews_count: number
  completed_bookings: number
  total_earnings: number
  /** عمولة خاصة تتجاوز نسبة المنصة العامة، أو null لاستخدام العامة. */
  commission_percent: number | null
  rejection_reason: string
  categories: string[]
  applied_at: string
  verified_at: string | null
}

export type DocumentType =
  | 'id_card'
  | 'commercial_register'
  | 'certificate'
  | 'insurance'
  | 'work_samples'

export type DocumentStatus = 'pending' | 'approved' | 'rejected'

export interface ProviderDocument {
  id: string
  provider_id: string
  type: DocumentType
  file_name: string
  /**
   * مسار الملف داخل حاوية `provider-docs`، بصيغة `<provider_id>/<doc_id>.<ext>`.
   * ليس رابطاً يُفتح مباشرة: الحاوية خاصة، والرابط القابل للفتح يُصدَر موقَّتاً
   * عند الطلب. يبقى فارغاً للمستندات المسجّلة قبل وجود التخزين.
   */
  file_url: string
  status: DocumentStatus
  note: string
  uploaded_at: string
}

export interface ProviderService {
  id: string
  provider_id: string
  provider_name: string
  category_id: string
  category_name: string
  title: string
  description: string
  price: number
  price_to: number | null
  unit: string
  /** نسبة العربون المطلوب دفعه لتأكيد الحجز. */
  deposit_percent: number
  duration_minutes: number
  cancellation_policy_id: string | null
  cancellation_policy_name: string
  is_active: boolean
}

// ---------------------------------------------------------------------------
// خطط الأعراس والحجوزات
// ---------------------------------------------------------------------------

export type PlanStatus = 'planning' | 'confirmed' | 'completed' | 'cancelled'

export interface WeddingPlan {
  id: string
  user_id: string
  user_name: string
  title: string
  wedding_date: string
  governorate: string
  guests_count: number
  budget: number
  status: PlanStatus
  notes: string
  created_at: string
  /** مجاميع محسوبة من الحجوزات المرتبطة — لا تُخزَّن حتى لا تتباعد. */
  services_count: number
  total_cost: number
  paid_amount: number
  remaining_amount: number
}

/**
 * دورة حياة الحجز.
 *
 * `pending_provider` مدفوع وينتظر رد مقدّم الخدمة؛ `rejected` اعتذر مقدّم
 * الخدمة فيُسترد كامل المدفوع؛ `cancelled` ألغى العميل فالاسترداد بالسلّم.
 */
export type BookingStatus =
  | 'pending_provider'
  | 'confirmed'
  | 'completed'
  | 'rejected'
  | 'cancelled'
  | 'expired'

export interface Booking {
  id: string
  reference: string
  user_id: string
  user_name: string
  provider_id: string
  provider_name: string
  service_id: string
  service_title: string
  category_id: string
  category_name: string
  plan_id: string | null
  event_date: string
  event_time: string | null
  governorate: string
  address: string
  guests_count: number
  notes: string
  status: BookingStatus
  total_price: number
  deposit_amount: number
  paid_amount: number
  refunded_amount: number
  commission_percent: number
  commission_amount: number
  /** سلّم الإلغاء منسوخاً وقت الحجز — تعديل السياسة لاحقاً لا يمسّه. */
  cancellation_rules: RefundRule[]
  rejection_reason: string
  cancel_reason: string
  created_at: string
  confirmed_at: string | null
  completed_at: string | null
  cancelled_at: string | null
}

// ---------------------------------------------------------------------------
// المالية
// ---------------------------------------------------------------------------

export type PaymentStatus = 'paid' | 'pending' | 'failed' | 'refunded'

/** طرق الدفع المتاحة في السوق اليمني. */
export type PaymentMethod =
  | 'jawali'
  | 'cash_wallet'
  | 'kuraimi'
  | 'bank_transfer'
  | 'card'
  | 'wallet'

export type PaymentKind =
  | 'deposit'
  | 'balance'
  | 'full'
  | 'subscription'
  | 'promotion'
  | 'refund'

export interface Payment {
  id: string
  reference: string
  user_id: string
  user_name: string
  provider_id: string | null
  provider_name: string
  booking_id: string | null
  booking_reference: string
  kind: PaymentKind
  description: string
  amount: number
  /** ما تحتفظ به المنصة من العملية. */
  platform_share: number
  /** المستحق لمقدّم الخدمة. */
  net_amount: number
  method: PaymentMethod
  status: PaymentStatus
  gateway_ref: string
  created_at: string
  refunded_at: string | null
}

export interface PaymentTotals {
  collected: number
  platformShare: number
  refunded: number
  refundedCount: number
  successRate: number
  byMethod: { method: PaymentMethod; amount: number }[]
}

export type SettlementStatus = 'pending' | 'approved' | 'paid' | 'on_hold'

/** تسوية مستحقات شريك عن فترة. */
export interface Settlement {
  id: string
  reference: string
  provider_id: string
  provider_name: string
  period_start: string
  period_end: string
  gross_amount: number
  commission_amount: number
  net_amount: number
  status: SettlementStatus
  method: string
  note: string
  created_at: string
  paid_at: string | null
  bookings_count: number
}

// ---------------------------------------------------------------------------
// الثقة: التقييمات والنزاعات
// ---------------------------------------------------------------------------

export type ReviewStatus = 'published' | 'hidden' | 'flagged'

export interface Review {
  id: string
  booking_id: string
  booking_reference: string
  user_id: string
  user_name: string
  provider_id: string
  provider_name: string
  rating: number
  comment: string
  status: ReviewStatus
  hidden_reason: string
  created_at: string
}

export type DisputeStatus = 'open' | 'investigating' | 'resolved' | 'closed'

export type DisputeCategory =
  | 'no_show'
  | 'quality'
  | 'payment'
  | 'cancellation'
  | 'behaviour'
  | 'other'

export interface Dispute {
  id: string
  reference: string
  booking_id: string
  booking_reference: string
  opened_by: 'customer' | 'provider'
  user_id: string
  user_name: string
  provider_id: string
  provider_name: string
  subject: string
  description: string
  category: DisputeCategory
  status: DisputeStatus
  resolution: string
  /** المبلغ الذي قرّرت الإدارة إعادته للعميل عند الحسم. */
  refund_amount: number
  resolved_by: string
  created_at: string
  resolved_at: string | null
}

export interface DisputeMessage {
  id: string
  dispute_id: string
  author: 'customer' | 'provider' | 'admin'
  author_name: string
  body: string
  created_at: string
}

// ---------------------------------------------------------------------------
// خدمة العملاء
// ---------------------------------------------------------------------------

export type TicketCategory =
  | 'account'
  | 'payment'
  | 'booking'
  | 'technical'
  | 'suggestion'
  | 'other'

export type TicketStatus = 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed'

export type TicketPriority = 'normal' | 'high' | 'urgent'

export interface SupportTicket {
  id: string
  reference: string
  opened_by: 'customer' | 'provider'
  user_id: string | null
  user_name: string
  provider_id: string | null
  provider_name: string
  /** اسم صاحب التذكرة أياً كان تطبيقه — يأتي من طريقة العرض. */
  requester_name: string
  subject: string
  category: TicketCategory
  booking_id: string | null
  booking_reference: string
  status: TicketStatus
  priority: TicketPriority
  assigned_to: string
  messages_count: number
  last_message: string | null
  created_at: string
  last_message_at: string
  /** أول ردّ من الإدارة — به يُقاس زمن الاستجابة. */
  first_response_at: string | null
  resolved_at: string | null
}

export interface SupportMessage {
  id: string
  ticket_id: string
  author: 'customer' | 'provider' | 'admin'
  author_name: string
  body: string
  /** ملاحظة بين المسؤولين لا يراها صاحب التذكرة — تحجبها RLS لا الواجهة. */
  is_internal: boolean
  created_at: string
}

// ---------------------------------------------------------------------------
// الدخل: الاشتراكات والإعلانات
// ---------------------------------------------------------------------------

export interface SubscriptionPlan {
  id: string
  name: string
  description: string
  price: number
  duration_days: number
  perks: string[]
  is_active: boolean
  subscribers_count: number
}

export type PromotionKind = 'featured' | 'banner' | 'category_top'

export type PromotionStatus = 'scheduled' | 'active' | 'ended' | 'cancelled'

export interface Promotion {
  id: string
  provider_id: string
  provider_name: string
  kind: PromotionKind
  placement: string
  category_name: string
  amount: number
  status: PromotionStatus
  impressions: number
  clicks: number
  starts_at: string
  ends_at: string
}

// ---------------------------------------------------------------------------
// التشغيل
// ---------------------------------------------------------------------------

export type NotificationStatus = 'sent' | 'scheduled' | 'draft' | 'failed'

export type Audience = 'all' | 'customers' | 'providers' | 'ios' | 'android' | 'active' | 'inactive'

export interface PushNotification {
  id: string
  title: string
  body: string
  audience: Audience
  status: NotificationStatus
  scheduled_at: string | null
  sent_at: string | null
  recipients: number
  opened: number
}

export interface AppVersion {
  id: string
  platform: Platform
  version: string
  build: number
  released_at: string
  force_update: boolean
  rollout_percent: number
  notes: string
}

export interface AppSettings {
  maintenance_mode: boolean
  maintenance_message: string
  allow_signups: boolean
  allow_provider_signups: boolean
  /** نسبة عمولة المنصة العامة. */
  commission_percent: number
  default_deposit_percent: number
  currency: string
  min_ios_version: string
  min_android_version: string
  support_email: string
  support_phone: string
  default_locale: string
}

// ---------------------------------------------------------------------------
// الصلاحيات وسجل العمليات
// ---------------------------------------------------------------------------

export type AdminRole = 'owner' | 'admin' | 'viewer'

export interface AdminAccount {
  user_id: string
  email: string
  role: AdminRole
  created_at: string
}

export interface AuditEntry {
  id: string
  actor_email: string
  action: string
  entity: string
  entity_id: string
  entity_label: string
  details: Record<string, unknown>
  created_at: string
}

// ---------------------------------------------------------------------------
// لوحة المعلومات
// ---------------------------------------------------------------------------

export interface MetricPoint {
  date: string
  value: number
}

export interface DailyBreakdown {
  date: string
  ios: number
  android: number
}

export interface Kpi {
  value: number
  /** التغيّر مقابل الفترة السابقة المساوية في الطول. */
  change: number
}

export interface DashboardStats {
  activeUsers: Kpi
  bookings: Kpi
  revenue: Kpi
  commission: Kpi
  bookingsByDay: MetricPoint[]
  installsByDay: DailyBreakdown[]
  /** الحجوزات موزّعة على أقسام الخدمات. */
  bookingsByCategory: { category: string; count: number }[]
  topGovernorates: { governorate: string; bookings: number }[]
  /** ما ينتظر تدخّل الإدارة الآن. */
  pendingProviders: number
  openTickets: number
  openDisputes: number
  pendingSettlements: number
  flaggedReviews: number
}

export type RangeDays = 7 | 30 | 90
