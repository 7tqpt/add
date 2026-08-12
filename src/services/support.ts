import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  SupportMessage,
  SupportTicket,
  TicketCategory,
  TicketPriority,
  TicketStatus,
} from '@/lib/types'
import { mockTicketMessages, mockTickets } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoTickets: SupportTicket[] = [...mockTickets]
const demoMessages: SupportMessage[] = [...mockTicketMessages]

export const TICKET_STATUS_LABEL: Record<TicketStatus, string> = {
  open: 'مفتوحة',
  in_progress: 'قيد المعالجة',
  waiting_customer: 'بانتظار العميل',
  resolved: 'تم الحل',
  closed: 'مغلقة',
}

export const TICKET_CATEGORY_LABEL: Record<TicketCategory, string> = {
  account: 'الحساب',
  payment: 'الدفع',
  booking: 'الحجوزات',
  technical: 'عطل فني',
  suggestion: 'اقتراح',
  other: 'أخرى',
}

export const TICKET_PRIORITY_LABEL: Record<TicketPriority, string> = {
  normal: 'عادية',
  high: 'مهمة',
  urgent: 'عاجلة',
}

export interface TicketQuery {
  search: string
  status: TicketStatus | 'all'
  category: TicketCategory | 'all'
  page: number
  pageSize: number
}

export async function listTickets(query: TicketQuery): Promise<Paged<SupportTicket>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoTickets
      .filter((ticket) => {
        if (query.status !== 'all' && ticket.status !== query.status) return false
        if (query.category !== 'all' && ticket.category !== query.category) return false
        if (!term) return true
        return (
          ticket.reference.toLowerCase().includes(term) ||
          ticket.subject.toLowerCase().includes(term) ||
          ticket.requester_name.toLowerCase().includes(term)
        )
      })
      .sort((a, b) => b.last_message_at.localeCompare(a.last_message_at))
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const from = query.page * query.pageSize
  let builder = requireSupabase()
    .from('v_admin_tickets')
    .select('*', { count: 'exact' })
    // الأحدث حركةً أولاً، لا الأحدث إنشاءً: التذكرة التي وصلها ردّ للتوّ هي
    // التي تنتظر جواباً، ولو فُتحت الأسبوع الماضي.
    .order('last_message_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.category !== 'all') builder = builder.eq('category', query.category)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `reference.ilike.%${safe}%,subject.ilike.%${safe}%,user_name.ilike.%${safe}%,provider_name.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as SupportTicket[], total: count ?? 0 }
}

export async function getTicket(id: string): Promise<SupportTicket | null> {
  if (!isSupabaseConfigured) return delay(demoTickets.find((t) => t.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('v_admin_tickets')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as SupportTicket | null) ?? null
}

export async function listTicketMessages(ticketId: string): Promise<SupportMessage[]> {
  if (!isSupabaseConfigured) {
    return delay(
      demoMessages
        .filter((message) => message.ticket_id === ticketId)
        .sort((a, b) => a.created_at.localeCompare(b.created_at)),
    )
  }

  const { data, error } = await requireSupabase()
    .from('support_messages')
    .select('*')
    .eq('ticket_id', ticketId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as SupportMessage[]
}

/**
 * ردّ الإدارة. الرسالة وتحديث الحالة والإشعار تجري كلها في دالة واحدة على
 * الخادم — تركها للواجهة يعني أن انقطاعاً في المنتصف يترك رسالةً بلا إشعار،
 * فيردّ المسؤول ولا يعلم العميل.
 */
export async function replyToTicket(
  ticket: SupportTicket,
  body: string,
  options: { internal?: boolean; newStatus?: TicketStatus } = {},
): Promise<void> {
  const internal = options.internal ?? false

  if (!isSupabaseConfigured) {
    demoMessages.push({
      id: `tmsg_${Date.now().toString(36)}`,
      ticket_id: ticket.id,
      author: 'admin',
      author_name: 'الإدارة',
      body,
      is_internal: internal,
      created_at: new Date().toISOString(),
    })
    const target = demoTickets.find((t) => t.id === ticket.id)
    if (target && !internal) {
      target.status = options.newStatus ?? 'waiting_customer'
      target.last_message_at = new Date().toISOString()
      target.messages_count += 1
      target.last_message = body
      target.first_response_at = target.first_response_at ?? new Date().toISOString()
      if (target.status === 'resolved' || target.status === 'closed') {
        target.resolved_at = target.resolved_at ?? new Date().toISOString()
      }
    }
    await delay(null, 300)
  } else {
    const { error } = await requireSupabase().rpc('admin_reply_ticket', {
      p_ticket_id: ticket.id,
      p_body: body,
      p_internal: internal,
      p_new_status: options.newStatus ?? null,
    })
    if (error) throw error
  }

  // الملاحظة الداخلية لا يراها صاحب التذكرة، لكنها إجراء إداري يُسجَّل.
  await recordAudit({
    action: internal ? 'ticket.note' : 'ticket.reply',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: `${ticket.reference} — ${ticket.subject}`,
    details: internal ? {} : { to: TICKET_STATUS_LABEL[options.newStatus ?? 'waiting_customer'] },
  })
}

export async function setTicketStatus(
  ticket: SupportTicket,
  status: TicketStatus,
): Promise<void> {
  const previous = ticket.status
  const resolved_at =
    status === 'resolved' || status === 'closed'
      ? (ticket.resolved_at ?? new Date().toISOString())
      : null

  if (!isSupabaseConfigured) {
    const target = demoTickets.find((t) => t.id === ticket.id)
    if (target) Object.assign(target, { status, resolved_at })
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('support_tickets')
      .update({ status, resolved_at })
      .eq('id', ticket.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'ticket.status',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: `${ticket.reference} — ${ticket.subject}`,
    details: { from: TICKET_STATUS_LABEL[previous], to: TICKET_STATUS_LABEL[status] },
  })
}

export async function setTicketPriority(
  ticket: SupportTicket,
  priority: TicketPriority,
): Promise<void> {
  const previous = ticket.priority

  if (!isSupabaseConfigured) {
    const target = demoTickets.find((t) => t.id === ticket.id)
    if (target) target.priority = priority
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('support_tickets')
      .update({ priority })
      .eq('id', ticket.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'ticket.priority',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: `${ticket.reference} — ${ticket.subject}`,
    details: { from: TICKET_PRIORITY_LABEL[previous], to: TICKET_PRIORITY_LABEL[priority] },
  })
}

/** عدد التذاكر التي تنتظر الإدارة — للوحة المعلومات. */
export async function countOpenTickets(): Promise<number> {
  if (!isSupabaseConfigured) {
    return delay(demoTickets.filter((t) => t.status === 'open' || t.status === 'in_progress').length)
  }
  const { count, error } = await requireSupabase()
    .from('v_admin_tickets')
    .select('id', { count: 'exact', head: true })
    .in('status', ['open', 'in_progress'])
  if (error) throw error
  return count ?? 0
}
