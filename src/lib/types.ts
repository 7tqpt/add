export type Platform = 'ios' | 'android'

export type UserStatus = 'active' | 'suspended' | 'pending'

export interface AppUser {
  id: string
  full_name: string
  email: string
  phone: string | null
  platform: Platform
  country: string
  status: UserStatus
  app_version: string
  sessions_count: number
  created_at: string
  last_seen_at: string | null
}

export type NotificationStatus = 'sent' | 'scheduled' | 'draft' | 'failed'

export type Audience = 'all' | 'ios' | 'android' | 'active' | 'inactive'

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
  min_ios_version: string
  min_android_version: string
  support_email: string
  default_locale: string
  /** Fixed fee a customer pays to open an order for offers. */
  booking_fee: number
}

/**
 * `owner` manages other admins, `admin` changes data but not admins, `viewer`
 * reads only. Enforced in RLS first; the UI mirrors it so disabled controls
 * explain themselves before a request is refused.
 */
export type AdminRole = 'owner' | 'admin' | 'viewer'

export interface AdminAccount {
  user_id: string
  email: string
  role: AdminRole
  created_at: string
}

export interface UserSession {
  id: string
  user_id: string
  started_at: string
  duration_seconds: number
  platform: Platform
  app_version: string
  country: string
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

/**
 * Order lifecycle.
 *
 * `new` is open for offers — no provider is attached yet. `confirmed` means the
 * customer accepted an offer and paid the balance; everything after that is
 * execution. `cancelled` can be reached from any stage before completion.
 */
export type OrderStatus =
  | 'new'
  | 'confirmed'
  | 'on_the_way'
  | 'in_progress'
  | 'completed'
  | 'closed'
  | 'cancelled'

export interface Order {
  id: string
  reference: string
  user_id: string
  user_name: string
  /** Null until an offer is accepted — a new order has no provider yet. */
  provider_id: string | null
  provider_name: string
  category: string
  city: string
  address: string
  description: string
  status: OrderStatus
  /** When the visit is booked for. */
  scheduled_at: string
  /** Fixed fee paid to open the order for offers. */
  booking_fee: number
  /** The accepted offer's price. Zero while still open for offers. */
  final_price: number
  /** The platform's cut of `final_price`, set when the offer is accepted. */
  platform_share: number
  accepted_offer_id: string | null
  cancel_reason: string
  created_at: string
  accepted_at: string | null
  completed_at: string | null
  cancelled_at: string | null
}

export type OfferStatus = 'pending' | 'accepted' | 'rejected' | 'withdrawn'

export interface OrderOffer {
  id: string
  order_id: string
  provider_id: string
  provider_name: string
  provider_rating: number
  price: number
  duration_minutes: number
  note: string
  status: OfferStatus
  created_at: string
}

export type PaymentStatus = 'paid' | 'pending' | 'failed' | 'refunded'

export type PaymentMethod = 'card' | 'mada' | 'apple_pay' | 'stc_pay' | 'wallet'

/**
 * What was paid for. An order produces two rows: the `booking_fee` charged to
 * open it for offers, then the `order` balance once an offer is accepted.
 */
export type PaymentKind = 'booking_fee' | 'order' | 'subscription' | 'topup'

/**
 * One row of the money ledger — every in-app payment, whatever it was for.
 *
 * `amount` is what the customer was charged. `platform_share` is what the app
 * keeps — a commission on a service order, the whole amount on a subscription
 * or top-up — and `net_amount` is what is owed onward to the provider, zero
 * when there is no provider involved.
 */
export interface Payment {
  id: string
  reference: string
  user_id: string
  user_name: string
  provider_id: string | null
  provider_name: string
  /** Set for booking fees and order balances; null for subscriptions and top-ups. */
  order_id: string | null
  order_reference: string
  kind: PaymentKind
  description: string
  amount: number
  platform_share: number
  net_amount: number
  method: PaymentMethod
  status: PaymentStatus
  gateway_ref: string
  created_at: string
  refunded_at: string | null
}

export interface PaymentTotals {
  /** Gross value of successful payments in range. */
  collected: number
  /** The app's cut of those payments. */
  platformShare: number
  refunded: number
  refundedCount: number
  /** Share of attempts that succeeded — failed attempts included in the base. */
  successRate: number
  byMethod: { method: PaymentMethod; amount: number }[]
}

export type TicketStatus = 'open' | 'pending' | 'resolved' | 'closed'
export type TicketPriority = 'low' | 'normal' | 'high' | 'urgent'
export type TicketCategory = 'bug' | 'billing' | 'account' | 'feature' | 'other'

export interface SupportTicket {
  id: string
  user_id: string | null
  user_name: string
  user_email: string
  subject: string
  category: TicketCategory
  status: TicketStatus
  priority: TicketPriority
  created_at: string
  updated_at: string
}

export interface TicketMessage {
  id: string
  ticket_id: string
  author: 'user' | 'admin'
  author_email: string
  body: string
  created_at: string
}

/**
 * `pending` is awaiting document review, `rejected` was turned down at review,
 * `suspended` was active and then stopped. Rejected and suspended are kept
 * apart because they answer different questions: never approved vs. no longer
 * trusted.
 */
export type ProviderStatus = 'pending' | 'active' | 'suspended' | 'rejected'

export interface ServiceProvider {
  id: string
  full_name: string
  business_name: string
  email: string
  phone: string
  category: string
  city: string
  status: ProviderStatus
  /** Mean of `reviews_count` ratings, 0–5. Zero when there are no reviews yet. */
  rating: number
  reviews_count: number
  completed_orders: number
  total_earnings: number
  /** Platform cut, as a percentage of each order. */
  commission_percent: number
  joined_at: string
  verified_at: string | null
}

export type DocumentType = 'id_card' | 'commercial_register' | 'certificate' | 'insurance'
export type DocumentStatus = 'pending' | 'approved' | 'rejected'

export interface ProviderDocument {
  id: string
  provider_id: string
  type: DocumentType
  file_name: string
  status: DocumentStatus
  note: string
  uploaded_at: string
}

export interface ProviderService {
  id: string
  provider_id: string
  title: string
  price: number
  duration_minutes: number
  active: boolean
}

export interface ProviderReview {
  id: string
  provider_id: string
  user_name: string
  rating: number
  comment: string
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

/** One page of rows plus the unfiltered total, for pagination controls. */
export interface Paged<T> {
  rows: T[]
  total: number
}

/** A single point on a time series. `date` is an ISO `YYYY-MM-DD` day. */
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
  /** Total over the selected range (or a current snapshot, for gauges). */
  value: number
  /** Fractional change vs. the immediately preceding range of equal length. */
  change: number
}

export interface DashboardStats {
  activeUsers: Kpi
  installs: Kpi
  sessions: Kpi
  revenue: Kpi
  /** Daily new installs, split by platform. */
  installsByDay: DailyBreakdown[]
  /** Daily sessions, one series. */
  sessionsByDay: MetricPoint[]
  /** Share of the install base per platform. */
  platformSplit: { platform: Platform; users: number }[]
  /** Top countries by user count. */
  topCountries: { country: string; users: number }[]
  crashFreeRate: number
}

/** Number of days a dashboard range covers. */
export type RangeDays = 7 | 30 | 90
