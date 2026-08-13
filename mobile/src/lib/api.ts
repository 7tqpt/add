import { isSupabaseConfigured, requireSupabase } from './supabase'
import {
  delay,
  demoBookings,
  demoCategories,
  demoGovernorates,
  demoPlans,
  demoServices,
  demoTicketMessages,
  demoTickets,
} from './demo'
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
 * كل ما يقرؤه التطبيق أو يكتبه.
 *
 * الكتابة كلها تمرّ بدوال `api_*` لا بجداول: الخادم هو من يحسب السعر والعربون
 * والعمولة وسلّم الإلغاء. لو قبِل سعراً من التطبيق لأمكن حجز قاعة بريال.
 */

// ---------------------------------------------------------------------------
// التسجيل
// ---------------------------------------------------------------------------

export async function registerProfile(input: {
  fullName: string
  phone: string
  governorate: string
  platform: 'ios' | 'android'
}): Promise<void> {
  const { error } = await requireSupabase().rpc('api_register_profile', {
    p_full_name: input.fullName,
    p_phone: input.phone,
    p_governorate: input.governorate,
    p_platform: input.platform,
  })
  if (error) throw error
}

export async function applyAsProvider(input: {
  businessName: string
  phone: string
  bio: string
  governorate: string
  categoryIds: string[]
}): Promise<void> {
  const { error } = await requireSupabase().rpc('api_apply_as_provider', {
    p_business_name: input.businessName,
    p_phone: input.phone,
    p_bio: input.bio,
    p_governorate: input.governorate,
    p_category_ids: input.categoryIds,
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// المرجعيات والاستكشاف
// ---------------------------------------------------------------------------

export async function listGovernorates(): Promise<Governorate[]> {
  if (!isSupabaseConfigured) return delay(demoGovernorates)
  const { data, error } = await requireSupabase()
    .from('governorates')
    .select('id, name')
    .eq('is_active', true)
    .order('sort_order')
  if (error) throw error
  return (data ?? []) as Governorate[]
}

export async function listCategories(): Promise<ServiceCategory[]> {
  if (!isSupabaseConfigured) return delay(demoCategories)
  const { data, error } = await requireSupabase()
    .from('service_categories')
    .select('id, name, slug, description, sort_order')
    .eq('is_active', true)
    .order('sort_order')
  if (error) throw error
  return (data ?? []) as ServiceCategory[]
}

export interface ServiceQuery {
  search?: string
  categoryId?: string | null
  governorate?: string | null
  limit?: number
}

export async function listServices(query: ServiceQuery = {}): Promise<Service[]> {
  if (!isSupabaseConfigured) {
    const term = query.search?.trim().toLowerCase() ?? ''
    return delay(
      demoServices.filter((item) => {
        if (query.categoryId && item.category_id !== query.categoryId) return false
        if (!term) return true
        return (
          item.title.toLowerCase().includes(term) ||
          item.provider_name.toLowerCase().includes(term)
        )
      }),
    )
  }
  // `select` أولاً ثم المرشّحات: `from()` يعيد مُنشئ جدول لا مُنشئ استعلام،
  // وليس فيه `order` ولا `eq` قبل أن يُختار شيء.
  let builder = requireSupabase()
    .from('v_services')
    .select('*')
    // المميَّزون أولاً ثم الأعلى تقييماً — وهو ما تبيعه المنصة في «الحملات».
    .order('provider_is_featured', { ascending: false })
    .order('provider_rating', { ascending: false })
    .limit(query.limit ?? 40)

  if (query.categoryId) builder = builder.eq('category_id', query.categoryId)
  if (query.governorate) builder = builder.eq('provider_governorate', query.governorate)

  const term = query.search?.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`title.ilike.%${safe}%,provider_name.ilike.%${safe}%`)
  }

  const { data, error } = await builder
  if (error) throw error
  return (data ?? []) as Service[]
}

export async function getService(id: string): Promise<Service | null> {
  if (!isSupabaseConfigured) return delay(demoServices.find((s) => s.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('v_services')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as Service | null) ?? null
}

// ---------------------------------------------------------------------------
// الحجوزات
// ---------------------------------------------------------------------------

export async function createBooking(input: {
  serviceId: string
  eventDate: string
  eventTime: string | null
  planId?: string | null
  guests: number
  address: string
  notes?: string
  payFull?: boolean
}): Promise<Booking> {
  const { data, error } = await requireSupabase().rpc('api_create_booking', {
    p_service_id: input.serviceId,
    p_event_date: input.eventDate,
    p_event_time: input.eventTime,
    p_plan_id: input.planId ?? null,
    p_guests_count: input.guests,
    p_address: input.address,
    p_notes: input.notes ?? '',
    p_pay_full: input.payFull ?? false,
  })
  if (error) throw error
  return (Array.isArray(data) ? data[0] : data) as Booking
}

export async function listMyBookings(): Promise<Booking[]> {
  if (!isSupabaseConfigured) return delay([...demoBookings])
  // لا شرط على المستخدم هنا: RLS تُرجع حجوزاته وحدها، وإضافة الشرط في التطبيق
  // تُوهم أنه هو الحاجز.
  const { data, error } = await requireSupabase()
    .from('bookings')
    .select('*')
    .order('event_date', { ascending: true })
  if (error) throw error
  return (data ?? []) as Booking[]
}

export async function cancelBooking(id: string, reason: string): Promise<void> {
  const { error } = await requireSupabase().rpc('api_cancel_booking', {
    p_booking_id: id,
    p_reason: reason,
  })
  if (error) throw error
}

export async function respondToBooking(
  id: string,
  accept: boolean,
  reason = '',
): Promise<void> {
  const { error } = await requireSupabase().rpc('api_respond_to_booking', {
    p_booking_id: id,
    p_accept: accept,
    p_reason: reason,
  })
  if (error) throw error
}

export async function completeBooking(id: string): Promise<void> {
  const { error } = await requireSupabase().rpc('api_complete_booking', {
    p_booking_id: id,
  })
  if (error) throw error
}

export async function submitReview(
  bookingId: string,
  rating: number,
  comment: string,
): Promise<void> {
  const { error } = await requireSupabase().rpc('api_submit_review', {
    p_booking_id: bookingId,
    p_rating: rating,
    p_comment: comment,
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// خطة العرس
// ---------------------------------------------------------------------------

export async function listMyPlans(): Promise<WeddingPlan[]> {
  if (!isSupabaseConfigured) return delay([...demoPlans])
  const { data, error } = await requireSupabase()
    .from('v_plan_summary')
    .select('*')
    .order('wedding_date', { ascending: true })
  if (error) throw error
  return (data ?? []) as WeddingPlan[]
}

export async function createPlan(input: {
  title: string
  weddingDate: string
  governorate: string
  guests: number
  budget: number
  notes?: string
}): Promise<void> {
  const client = requireSupabase()
  const { data: me } = await client
    .from('app_users')
    .select('id, full_name')
    .maybeSingle()
  if (!me) throw new Error('أكمل ملفك أولاً.')

  const { error } = await client.from('wedding_plans').insert({
    user_id: me.id,
    user_name: me.full_name,
    title: input.title,
    wedding_date: input.weddingDate,
    governorate: input.governorate,
    guests_count: input.guests,
    budget: input.budget,
    notes: input.notes ?? '',
  })
  if (error) throw error
}

// ---------------------------------------------------------------------------
// خدمة العملاء
// ---------------------------------------------------------------------------

export async function listMyTickets(): Promise<SupportTicket[]> {
  if (!isSupabaseConfigured) return delay([...demoTickets])
  const { data, error } = await requireSupabase()
    .from('support_tickets')
    .select('id, reference, subject, category, status, created_at, last_message_at')
    .order('last_message_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as SupportTicket[]
}

export async function listTicketMessages(ticketId: string): Promise<SupportMessage[]> {
  if (!isSupabaseConfigured) {
    return delay(demoTicketMessages.filter((m) => m.ticket_id === ticketId))
  }
  // الملاحظات الداخلية محجوبة بسياسة RLS لا باستعلام — لا شرط هنا عليها.
  const { data, error } = await requireSupabase()
    .from('support_messages')
    .select('id, ticket_id, author, author_name, body, created_at')
    .eq('ticket_id', ticketId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as SupportMessage[]
}

export async function openTicket(input: {
  subject: string
  body: string
  category: string
  bookingId?: string | null
  asProvider?: boolean
}): Promise<void> {
  const { error } = await requireSupabase().rpc('api_open_ticket', {
    p_subject: input.subject,
    p_body: input.body,
    p_category: input.category,
    p_booking_id: input.bookingId ?? null,
    p_as_provider: input.asProvider ?? false,
  })
  if (error) throw error
}

export async function replyTicket(ticketId: string, body: string): Promise<void> {
  const { error } = await requireSupabase().rpc('api_reply_ticket', {
    p_ticket_id: ticketId,
    p_body: body,
  })
  if (error) throw error
}
