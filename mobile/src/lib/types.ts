/**
 * أنواع التطبيق — ما يقرؤه فعلاً لا كل ما في القاعدة.
 *
 * أضيق من `src/lib/types.ts` في اللوحة عمداً: التطبيق لا يرى العمولات ولا
 * مستحقات الشركاء ولا سجل العمليات، فلا داعي لأن يعرف شكلها.
 */

export type Platform = 'ios' | 'android'

export interface Governorate {
  id: string
  name: string
}

export interface ServiceCategory {
  id: string
  name: string
  slug: string
  description: string
  sort_order: number
}

/**
 * صفّ `v_services` بأسمائه كما هي في القاعدة.
 *
 * `provider_governorate` لا `governorate`: الطريقة تجمع جدولين فيهما العمود
 * نفسه، فسُمّي بمصدره. وتسميته هنا باسمٍ أقصر تُنتج `undefined` صامتة على
 * الشاشة بدل خطأ يُقرأ.
 */
export interface Service {
  id: string
  provider_id: string
  provider_name: string
  provider_governorate: string
  provider_rating: number
  provider_reviews_count: number
  provider_is_featured: boolean
  category_id: string
  category_name: string
  category_slug: string
  title: string
  description: string
  price: number
  price_to: number | null
  unit: string
  deposit_percent: number
  duration_minutes: number
  images: string[]
  attributes: Record<string, unknown>
  cancellation_policy_name: string | null
}

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
  created_at: string
}

export type PlanStatus = 'planning' | 'confirmed' | 'completed' | 'cancelled'

export interface WeddingPlan {
  id: string
  title: string
  wedding_date: string
  governorate: string
  guests_count: number
  budget: number
  status: PlanStatus
  notes: string
  services_count: number
  total_cost: number
  paid_amount: number
  remaining_amount: number
}

export type TicketStatus = 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed'

export type TicketCategory =
  | 'account'
  | 'payment'
  | 'booking'
  | 'technical'
  | 'suggestion'
  | 'other'

export interface SupportTicket {
  id: string
  reference: string
  subject: string
  category: TicketCategory
  status: TicketStatus
  created_at: string
  last_message_at: string
}

export interface SupportMessage {
  id: string
  ticket_id: string
  author: 'customer' | 'provider' | 'admin'
  author_name: string
  body: string
  created_at: string
}

export interface AppNotification {
  id: string
  kind: string
  title: string
  body: string
  data: Record<string, unknown>
  read_at: string | null
  created_at: string
}

/** ملف مقدّم الخدمة كما يراه صاحبه. */
export interface ProviderProfile {
  id: string
  full_name: string
  business_name: string
  phone: string
  bio: string
  governorate: string
  status: 'pending' | 'verified' | 'rejected' | 'suspended'
  rating: number
  reviews_count: number
  completed_bookings: number
  total_earnings: number
  rejection_reason: string
}

export interface ProviderDocument {
  id: string
  type: 'id_card' | 'commercial_register' | 'certificate' | 'insurance' | 'work_samples'
  file_name: string
  file_url: string
  status: 'pending' | 'approved' | 'rejected'
  note: string
  uploaded_at: string
}
