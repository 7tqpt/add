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
