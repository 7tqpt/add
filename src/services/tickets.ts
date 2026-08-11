import { requireSupabase } from '@/lib/supabase'
import type {
  Paged,
  SupportTicket,
  TicketCategory,
  TicketMessage,
  TicketPriority,
  TicketStatus,
} from '@/lib/types'
import { mockTicketMessages, mockTickets } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoTickets: SupportTicket[] = [...mockTickets]
const demoMessages: TicketMessage[] = [...mockTicketMessages]

export interface TicketQuery {
  status: TicketStatus | 'all'
  priority: TicketPriority | 'all'
  search: string
  page: number
  pageSize: number
}

export async function listTickets(query: TicketQuery): Promise<Paged<SupportTicket>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoTickets.filter((ticket) => {
      if (query.status !== 'all' && ticket.status !== query.status) return false
      if (query.priority !== 'all' && ticket.priority !== query.priority) return false
      if (!term) return true
      return (
        ticket.subject.toLowerCase().includes(term) ||
        ticket.user_name.toLowerCase().includes(term) ||
        ticket.user_email.toLowerCase().includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('support_tickets')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.priority !== 'all') builder = builder.eq('priority', query.priority)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `subject.ilike.%${safe}%,user_name.ilike.%${safe}%,user_email.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as SupportTicket[], total: count ?? 0 }
}

export async function listTicketMessages(ticketId: string): Promise<TicketMessage[]> {
  if (!isSupabaseConfigured) {
    return delay(
      demoMessages
        .filter((message) => message.ticket_id === ticketId)
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()),
    )
  }

  const { data, error } = await requireSupabase()
    .from('ticket_messages')
    .select('*')
    .eq('ticket_id', ticketId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? []) as TicketMessage[]
}

export async function setTicketStatus(
  ticket: SupportTicket,
  status: TicketStatus,
): Promise<void> {
  // Captured before the write — the demo store mutates this object in place.
  const previous = ticket.status
  await patchTicket(ticket, { status })
  await recordAudit({
    action: 'ticket.status',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: ticket.subject,
    details: { from: TICKET_STATUS_LABEL[previous], to: TICKET_STATUS_LABEL[status] },
  })
}

export async function setTicketPriority(
  ticket: SupportTicket,
  priority: TicketPriority,
): Promise<void> {
  const previous = ticket.priority
  await patchTicket(ticket, { priority })
  await recordAudit({
    action: 'ticket.priority',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: ticket.subject,
    details: { from: TICKET_PRIORITY_LABEL[previous], to: TICKET_PRIORITY_LABEL[priority] },
  })
}

async function patchTicket(ticket: SupportTicket, changes: Partial<SupportTicket>): Promise<void> {
  const updated_at = new Date().toISOString()

  if (!isSupabaseConfigured) {
    const target = demoTickets.find((candidate) => candidate.id === ticket.id)
    if (target) Object.assign(target, changes, { updated_at })
    await delay(null, 200)
    return
  }

  const { error } = await requireSupabase()
    .from('support_tickets')
    .update({ ...changes, updated_at })
    .eq('id', ticket.id)
  if (error) throw error
}

export async function replyToTicket(
  ticket: SupportTicket,
  body: string,
  authorEmail: string,
): Promise<void> {
  const created_at = new Date().toISOString()

  if (!isSupabaseConfigured) {
    demoMessages.push({
      id: `msg_${Date.now().toString(36)}`,
      ticket_id: ticket.id,
      author: 'admin',
      author_email: authorEmail,
      body,
      created_at,
    })
    // Replying moves an untouched ticket out of the unanswered queue.
    const target = demoTickets.find((candidate) => candidate.id === ticket.id)
    if (target) {
      target.updated_at = created_at
      if (target.status === 'open') target.status = 'pending'
    }
    await delay(null, 320)
  } else {
    const client = requireSupabase()
    const { error } = await client.from('ticket_messages').insert({
      ticket_id: ticket.id,
      author: 'admin',
      author_email: authorEmail,
      body,
    })
    if (error) throw error

    const { error: updateError } = await client
      .from('support_tickets')
      .update({
        updated_at: created_at,
        ...(ticket.status === 'open' ? { status: 'pending' } : {}),
      })
      .eq('id', ticket.id)
    if (updateError) throw updateError
  }

  await recordAudit({
    action: 'ticket.reply',
    entity: 'ticket',
    entityId: ticket.id,
    entityLabel: ticket.subject,
  })
}

export const TICKET_STATUS_LABEL: Record<TicketStatus, string> = {
  open: 'مفتوح',
  pending: 'قيد المعالجة',
  resolved: 'تم الحل',
  closed: 'مغلق',
}

export const TICKET_PRIORITY_LABEL: Record<TicketPriority, string> = {
  urgent: 'عاجل',
  high: 'مرتفع',
  normal: 'عادي',
  low: 'منخفض',
}

export const TICKET_CATEGORY_LABEL: Record<TicketCategory, string> = {
  bug: 'عطل',
  billing: 'فوترة',
  account: 'حساب',
  feature: 'اقتراح',
  other: 'أخرى',
}
