import type { BookingStatus, TicketStatus } from './types'

export const BOOKING_STATUS_LABEL: Record<BookingStatus, string> = {
  pending_provider: 'بانتظار مقدّم الخدمة',
  confirmed: 'مؤكد',
  completed: 'منفّذ',
  rejected: 'مرفوض',
  cancelled: 'ملغي',
  expired: 'منتهٍ',
}

export const BOOKING_STATUS_TONE: Record<BookingStatus, 'good' | 'warning' | 'critical' | 'neutral'> = {
  pending_provider: 'warning',
  confirmed: 'good',
  completed: 'good',
  rejected: 'critical',
  cancelled: 'neutral',
  expired: 'neutral',
}

export const TICKET_STATUS_LABEL: Record<TicketStatus, string> = {
  open: 'مفتوحة',
  in_progress: 'قيد المعالجة',
  waiting_customer: 'بانتظار ردّك',
  resolved: 'تم الحل',
  closed: 'مغلقة',
}

export const TICKET_CATEGORIES: { value: string; label: string }[] = [
  { value: 'booking', label: 'الحجوزات' },
  { value: 'payment', label: 'الدفع' },
  { value: 'account', label: 'الحساب' },
  { value: 'technical', label: 'عطل فني' },
  { value: 'suggestion', label: 'اقتراح' },
  { value: 'other', label: 'أخرى' },
]
