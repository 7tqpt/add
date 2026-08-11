import { requireSupabase } from '@/lib/supabase'
import type {
  DocumentStatus,
  Paged,
  ProviderDocument,
  ProviderReview,
  ProviderService,
  ProviderStatus,
  ServiceProvider,
} from '@/lib/types'
import {
  PROVIDER_CATEGORIES,
  PROVIDER_CITIES,
  mockProviderDocuments,
  mockProviderReviews,
  mockProviderServices,
  mockProviders,
} from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoProviders: ServiceProvider[] = [...mockProviders]
const demoDocuments: ProviderDocument[] = [...mockProviderDocuments]

export { PROVIDER_CATEGORIES, PROVIDER_CITIES }

export interface ProviderQuery {
  search: string
  status: ProviderStatus | 'all'
  category: string | 'all'
  city: string | 'all'
  page: number
  pageSize: number
}

export async function listProviders(query: ProviderQuery): Promise<Paged<ServiceProvider>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoProviders.filter((provider) => {
      if (query.status !== 'all' && provider.status !== query.status) return false
      if (query.category !== 'all' && provider.category !== query.category) return false
      if (query.city !== 'all' && provider.city !== query.city) return false
      if (!term) return true
      return (
        provider.full_name.toLowerCase().includes(term) ||
        provider.business_name.toLowerCase().includes(term) ||
        provider.email.toLowerCase().includes(term) ||
        provider.phone.includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('service_providers')
    .select('*', { count: 'exact' })
    .order('joined_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.category !== 'all') builder = builder.eq('category', query.category)
  if (query.city !== 'all') builder = builder.eq('city', query.city)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(
      `full_name.ilike.%${safe}%,business_name.ilike.%${safe}%,email.ilike.%${safe}%,phone.ilike.%${safe}%`,
    )
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as ServiceProvider[], total: count ?? 0 }
}

export async function getProvider(id: string): Promise<ServiceProvider | null> {
  if (!isSupabaseConfigured) {
    return delay(demoProviders.find((provider) => provider.id === id) ?? null)
  }

  const { data, error } = await requireSupabase()
    .from('service_providers')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as ServiceProvider | null) ?? null
}

export interface ProviderPortfolio {
  documents: ProviderDocument[]
  services: ProviderService[]
  reviews: ProviderReview[]
}

/** Everything the provider-detail screen shows below the profile header. */
export async function getProviderPortfolio(providerId: string): Promise<ProviderPortfolio> {
  if (!isSupabaseConfigured) {
    return delay({
      documents: demoDocuments.filter((row) => row.provider_id === providerId),
      services: mockProviderServices.filter((row) => row.provider_id === providerId),
      reviews: mockProviderReviews
        .filter((row) => row.provider_id === providerId)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    })
  }

  const client = requireSupabase()
  const [documents, services, reviews] = await Promise.all([
    client.from('provider_documents').select('*').eq('provider_id', providerId),
    client.from('provider_services').select('*').eq('provider_id', providerId),
    client
      .from('provider_reviews')
      .select('*')
      .eq('provider_id', providerId)
      .order('created_at', { ascending: false }),
  ])

  if (documents.error) throw documents.error
  if (services.error) throw services.error
  if (reviews.error) throw reviews.error

  return {
    documents: (documents.data ?? []) as ProviderDocument[],
    services: (services.data ?? []) as ProviderService[],
    reviews: (reviews.data ?? []) as ProviderReview[],
  }
}

export async function setProviderStatus(
  provider: ServiceProvider,
  status: ProviderStatus,
): Promise<void> {
  // Read first: the demo store hands out live references, so the write below
  // mutates the very object this argument points at.
  const previous = provider.status
  // Approving stamps the verification date; the other transitions leave it as
  // the historical record of when this provider was first trusted.
  const verified_at =
    status === 'active' && !provider.verified_at ? new Date().toISOString() : provider.verified_at

  if (!isSupabaseConfigured) {
    const target = demoProviders.find((candidate) => candidate.id === provider.id)
    if (target) {
      target.status = status
      target.verified_at = verified_at
    }
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('service_providers')
      .update({ status, verified_at })
      .eq('id', provider.id)
    if (error) throw error
  }

  await recordAudit({
    action: `provider.${status}`,
    entity: 'provider',
    entityId: provider.id,
    entityLabel: provider.business_name || provider.full_name,
    details: { from: PROVIDER_STATUS_LABEL[previous], to: PROVIDER_STATUS_LABEL[status] },
  })
}

export async function setProviderCommission(
  provider: ServiceProvider,
  percent: number,
): Promise<void> {
  const clamped = Math.min(100, Math.max(0, Math.round(percent)))
  const previous = provider.commission_percent

  if (!isSupabaseConfigured) {
    const target = demoProviders.find((candidate) => candidate.id === provider.id)
    if (target) target.commission_percent = clamped
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('service_providers')
      .update({ commission_percent: clamped })
      .eq('id', provider.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'provider.commission',
    entity: 'provider',
    entityId: provider.id,
    entityLabel: provider.business_name || provider.full_name,
    details: { from: `${previous}%`, to: `${clamped}%` },
  })
}

export async function setDocumentStatus(
  provider: ServiceProvider,
  document: ProviderDocument,
  status: DocumentStatus,
  note = '',
): Promise<void> {
  const previous = document.status

  if (!isSupabaseConfigured) {
    const target = demoDocuments.find((candidate) => candidate.id === document.id)
    if (target) {
      target.status = status
      target.note = note
    }
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('provider_documents')
      .update({ status, note })
      .eq('id', document.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'provider.document',
    entity: 'provider',
    entityId: provider.id,
    entityLabel: `${provider.business_name || provider.full_name} — ${DOCUMENT_TYPE_LABEL[document.type]}`,
    details: { from: DOCUMENT_STATUS_LABEL[previous], to: DOCUMENT_STATUS_LABEL[status] },
  })
}

export const PROVIDER_STATUS_LABEL: Record<ProviderStatus, string> = {
  pending: 'بانتظار التوثيق',
  active: 'موثّق ونشط',
  suspended: 'موقوف',
  rejected: 'مرفوض',
}

export const DOCUMENT_TYPE_LABEL: Record<string, string> = {
  id_card: 'الهوية الوطنية',
  commercial_register: 'السجل التجاري',
  certificate: 'شهادة المهنة',
  insurance: 'وثيقة التأمين',
}

export const DOCUMENT_STATUS_LABEL: Record<DocumentStatus, string> = {
  pending: 'قيد المراجعة',
  approved: 'مقبول',
  rejected: 'مرفوض',
}
