import { requireSupabase } from '@/lib/supabase'
import type {
  AppUser,
  Paged,
  Payment,
  ProviderDocument,
  ProviderService,
  ServiceProvider,
  ProviderStatus,
  UserDevice,
  UserSession,
  UserStatus,
} from '@/lib/types'
import {
  mockDocuments,
  mockGovernorates,
  mockPayments,
  mockProviders,
  mockServices,
  mockUserDevices,
  mockUserSessions,
  mockUsers,
} from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

export const GOVERNORATES = mockGovernorates.map((g) => g.name)

// ---------------------------------------------------------------------------
// المستخدمون
// ---------------------------------------------------------------------------

const demoUsers: AppUser[] = [...mockUsers]

export interface UserQuery {
  search: string
  status: UserStatus | 'all'
  governorate: string | 'all'
  page: number
  pageSize: number
}

export async function listUsers(query: UserQuery): Promise<Paged<AppUser>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoUsers.filter((user) => {
      if (query.status !== 'all' && user.status !== query.status) return false
      if (query.governorate !== 'all' && user.governorate !== query.governorate) return false
      if (!term) return true
      return (
        user.full_name.toLowerCase().includes(term) ||
        user.email.toLowerCase().includes(term) ||
        user.phone.includes(term)
      )
    })
    const start = query.page * query.pageSize
    return delay({ rows: filtered.slice(start, start + query.pageSize), total: filtered.length })
  }

  const client = requireSupabase()
  const from = query.page * query.pageSize
  let builder = client
    .from('app_users')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.governorate !== 'all') builder = builder.eq('governorate', query.governorate)

  const term = query.search.trim()
  if (term) {
    const safe = term.replace(/[,()]/g, ' ')
    builder = builder.or(`full_name.ilike.%${safe}%,email.ilike.%${safe}%,phone.ilike.%${safe}%`)
  }

  const { data, error, count } = await builder
  if (error) throw error
  return { rows: (data ?? []) as AppUser[], total: count ?? 0 }
}

export async function getUser(id: string): Promise<AppUser | null> {
  if (!isSupabaseConfigured) return delay(demoUsers.find((u) => u.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('app_users').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return (data as AppUser | null) ?? null
}

export async function updateUserStatus(user: AppUser, status: UserStatus): Promise<void> {
  // Read first: the demo store hands out live references.
  const previous = user.status

  if (!isSupabaseConfigured) {
    const target = demoUsers.find((candidate) => candidate.id === user.id)
    if (target) target.status = status
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('app_users').update({ status }).eq('id', user.id)
    if (error) throw error
  }

  await recordAudit({
    action: status === 'suspended' ? 'user.suspend' : 'user.activate',
    entity: 'user',
    entityId: user.id,
    entityLabel: user.full_name,
    details: { from: USER_STATUS_LABEL[previous], to: USER_STATUS_LABEL[status] },
  })
}

export interface UserActivity {
  sessions: UserSession[]
  devices: UserDevice[]
  payments: Payment[]
}

export async function getUserActivity(userId: string): Promise<UserActivity> {
  if (!isSupabaseConfigured) {
    return delay({
      sessions: mockUserSessions
        .filter((s) => s.user_id === userId)
        .sort((a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime())
        .slice(0, 20),
      devices: mockUserDevices.filter((d) => d.user_id === userId),
      payments: mockPayments.filter((p) => p.user_id === userId),
    })
  }

  const client = requireSupabase()
  const [sessions, devices, payments] = await Promise.all([
    client.from('user_sessions').select('*').eq('user_id', userId)
      .order('started_at', { ascending: false }).limit(20),
    client.from('user_devices').select('*').eq('user_id', userId),
    client.from('payments').select('*').eq('user_id', userId)
      .order('created_at', { ascending: false }),
  ])
  if (sessions.error) throw sessions.error
  if (devices.error) throw devices.error
  if (payments.error) throw payments.error

  return {
    sessions: (sessions.data ?? []) as UserSession[],
    devices: (devices.data ?? []) as UserDevice[],
    payments: (payments.data ?? []) as Payment[],
  }
}

export const USER_STATUS_LABEL: Record<UserStatus, string> = {
  active: 'نشط',
  suspended: 'موقوف',
  pending: 'بانتظار التفعيل',
}

// ---------------------------------------------------------------------------
// مقدّمو الخدمة
// ---------------------------------------------------------------------------

const demoProviders: ServiceProvider[] = [...mockProviders]
const demoDocuments: ProviderDocument[] = [...mockDocuments]

export interface ProviderQuery {
  search: string
  status: ProviderStatus | 'all'
  category: string | 'all'
  governorate: string | 'all'
  page: number
  pageSize: number
}

export async function listProviders(query: ProviderQuery): Promise<Paged<ServiceProvider>> {
  if (!isSupabaseConfigured) {
    const term = query.search.trim().toLowerCase()
    const filtered = demoProviders.filter((provider) => {
      if (query.status !== 'all' && provider.status !== query.status) return false
      if (query.category !== 'all' && !provider.categories.includes(query.category)) return false
      if (query.governorate !== 'all' && provider.governorate !== query.governorate) return false
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
    .from('v_admin_providers')
    .select('*', { count: 'exact' })
    .order('applied_at', { ascending: false })
    .range(from, from + query.pageSize - 1)

  if (query.status !== 'all') builder = builder.eq('status', query.status)
  if (query.governorate !== 'all') builder = builder.eq('governorate', query.governorate)

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
  if (!isSupabaseConfigured) return delay(demoProviders.find((p) => p.id === id) ?? null)
  const { data, error } = await requireSupabase()
    .from('v_admin_providers').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return (data as ServiceProvider | null) ?? null
}

export interface ProviderPortfolio {
  documents: ProviderDocument[]
  services: ProviderService[]
  /**
   * روابط فتح المستندات، مفتاحها معرّف المستند. المستند بلا ملف مرفوع لا مفتاح
   * له هنا — وهو ما تعتمد عليه الشاشة لتفرّق بين «افتح» و«لا يوجد ملف».
   */
  documentUrls: Record<string, string>
}

const DOCS_BUCKET = 'provider-docs'

/** مدّة صلاحية رابط المستند. تكفي جلسة مراجعة، ولا تصلح للمشاركة. */
const SIGNED_URL_TTL_SECONDS = 600

/**
 * يحوّل مسارات التخزين إلى روابط موقَّتة قابلة للفتح.
 *
 * الحاوية خاصة، فلا يوجد رابط دائم لصورة هوية — وهذا مقصود. الروابط تُصدَر
 * دفعةً واحدة مع تحميل الصفحة لا عند الضغط: الإصدار عند الضغط يعني `await`
 * قبل `window.open`، وحينها يحجب المتصفّح النافذة باعتبارها لم تنشأ عن نقرة.
 *
 * فشل الإصدار لا يُسقط الصفحة: المستند يظهر بلا زر فتح، وبقية الشاشة تعمل.
 */
async function signDocuments(documents: ProviderDocument[]): Promise<Record<string, string>> {
  const stored = documents.filter((doc) => doc.file_url)
  if (stored.length === 0) return {}

  const { data, error } = await requireSupabase()
    .storage.from(DOCS_BUCKET)
    .createSignedUrls(
      stored.map((doc) => doc.file_url),
      SIGNED_URL_TTL_SECONDS,
    )
  if (error || !data) return {}

  const urls: Record<string, string> = {}
  data.forEach((entry, index) => {
    const doc = stored[index]
    if (doc && entry.signedUrl && !entry.error) urls[doc.id] = entry.signedUrl
  })
  return urls
}

/**
 * مستند بديل للوضع التجريبي.
 *
 * بلا هذا يظهر الوضع التجريبي وكأن زرّ «عرض» غير موجود أصلاً، فيبدو النقص
 * ميزةً ناقصة لا بيانات ناقصة. الصورة تُبنى في المتصفّح فلا ملف يُرفع ولا طلب
 * شبكة يُرسل.
 *
 * blob: لا data:. المتصفّحات تمنع الانتقال بالمستوى الأعلى إلى روابط data:
 * منذ سنوات — كانت وسيلةً شائعة للتصيّد — فالضغط على «عرض» ما كان ليفتح شيئاً.
 */
function demoDocumentUrl(label: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="820">
    <rect width="100%" height="100%" fill="#f5f3ee"/>
    <rect x="30" y="30" width="540" height="760" fill="#fff" stroke="#d9d2c5"/>
    <text x="300" y="380" text-anchor="middle" font-family="sans-serif" font-size="30" fill="#9a6a00">${label}</text>
    <text x="300" y="430" text-anchor="middle" font-family="sans-serif" font-size="20" fill="#8a8375">مستند تجريبي — لا يوجد ملف حقيقي</text>
  </svg>`
  return URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }))
}

export async function getProviderPortfolio(providerId: string): Promise<ProviderPortfolio> {
  if (!isSupabaseConfigured) {
    const documents = demoDocuments.filter((d) => d.provider_id === providerId)
    return delay({
      documents,
      services: mockServices.filter((s) => s.provider_id === providerId),
      documentUrls: Object.fromEntries(
        documents.map((doc) => [doc.id, demoDocumentUrl(DOCUMENT_TYPE_LABEL[doc.type] ?? doc.type)]),
      ),
    })
  }

  const client = requireSupabase()
  const [documents, services] = await Promise.all([
    client.from('provider_documents').select('*').eq('provider_id', providerId),
    client.from('v_admin_services').select('*').eq('provider_id', providerId),
  ])
  if (documents.error) throw documents.error
  if (services.error) throw services.error

  const rows = (documents.data ?? []) as ProviderDocument[]
  return {
    documents: rows,
    services: (services.data ?? []) as ProviderService[],
    documentUrls: await signDocuments(rows),
  }
}

export async function setProviderStatus(
  provider: ServiceProvider,
  status: ProviderStatus,
  reason = '',
): Promise<void> {
  const previous = provider.status
  // Verification stamps the date once; later transitions keep the original as
  // the record of when this provider was first trusted.
  const verified_at =
    status === 'verified' && !provider.verified_at ? new Date().toISOString() : provider.verified_at

  const patch = { status, verified_at, rejection_reason: status === 'rejected' ? reason : '' }

  if (!isSupabaseConfigured) {
    const target = demoProviders.find((candidate) => candidate.id === provider.id)
    if (target) Object.assign(target, patch)
    await delay(null, 240)
  } else {
    const { error } = await requireSupabase()
      .from('service_providers').update(patch).eq('id', provider.id)
    if (error) throw error
  }

  await recordAudit({
    action: `provider.${status}`,
    entity: 'provider',
    entityId: provider.id,
    entityLabel: provider.business_name || provider.full_name,
    details: {
      from: PROVIDER_STATUS_LABEL[previous],
      to: PROVIDER_STATUS_LABEL[status],
      ...(reason ? { reason } : {}),
    },
  })
}

export async function setDocumentStatus(
  provider: ServiceProvider,
  document: ProviderDocument,
  status: DocumentReview,
  note = '',
): Promise<void> {
  const previous = document.status

  if (!isSupabaseConfigured) {
    const target = demoDocuments.find((candidate) => candidate.id === document.id)
    if (target) Object.assign(target, { status, note })
    await delay(null, 200)
  } else {
    const { error } = await requireSupabase()
      .from('provider_documents').update({ status, note }).eq('id', document.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'provider.document',
    entity: 'provider',
    entityId: provider.id,
    entityLabel: `${provider.business_name} — ${DOCUMENT_TYPE_LABEL[document.type]}`,
    details: { from: DOCUMENT_STATUS_LABEL[previous], to: DOCUMENT_STATUS_LABEL[status] },
  })
}

type DocumentReview = ProviderDocument['status']

export async function setProviderCommission(
  provider: ServiceProvider,
  percent: number | null,
): Promise<void> {
  const previous = provider.commission_percent
  const clamped = percent === null ? null : Math.min(100, Math.max(0, Math.round(percent)))

  if (!isSupabaseConfigured) {
    const target = demoProviders.find((candidate) => candidate.id === provider.id)
    if (target) target.commission_percent = clamped
    await delay(null, 220)
  } else {
    const { error } = await requireSupabase()
      .from('service_providers').update({ commission_percent: clamped }).eq('id', provider.id)
    if (error) throw error
  }

  await recordAudit({
    action: 'provider.commission',
    entity: 'provider',
    entityId: provider.id,
    entityLabel: provider.business_name,
    details: {
      from: previous === null ? 'العمولة العامة' : `${previous}%`,
      to: clamped === null ? 'العمولة العامة' : `${clamped}%`,
    },
  })
}

export const PROVIDER_STATUS_LABEL: Record<ProviderStatus, string> = {
  pending: 'قيد المراجعة',
  verified: 'موثّق',
  rejected: 'مرفوض',
  suspended: 'موقوف',
}

export const DOCUMENT_TYPE_LABEL: Record<string, string> = {
  id_card: 'الهوية الوطنية',
  commercial_register: 'السجل التجاري',
  certificate: 'شهادة المهنة',
  insurance: 'وثيقة التأمين',
  work_samples: 'نماذج الأعمال',
}

export const DOCUMENT_STATUS_LABEL: Record<string, string> = {
  pending: 'قيد المراجعة',
  approved: 'مقبول',
  rejected: 'مرفوض',
}
