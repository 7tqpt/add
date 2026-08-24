import { useCallback, useEffect, useState } from 'react'
import { Search, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDateTime, formatMoney, formatNumber } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import {
  AUDIT_ACTION_LABEL,
  AUDIT_ENTITY_LABEL,
  clearAuditLog,
  listAudit,
  type AuditQuery,
} from '@/services/audit'
import { errorText } from '@/services/base'

const PAGE_SIZE = 15
const EXPORT_LIMIT = 5000

/** Renders `details` as a short human sentence rather than raw JSON. */
function describe(details: Record<string, unknown>): string {
  const parts: string[] = []

  // Some actions have no "before" — accepting an offer assigns a provider where
  // there was none — so a one-sided change reads as a destination, not a move.
  if ('from' in details && 'to' in details) {
    parts.push(`من «${format(details.from)}» إلى «${format(details.to)}»`)
  } else if ('to' in details) {
    parts.push(`إلى «${format(details.to)}»`)
  }
  if (Array.isArray(details.changed) && details.changed.length > 0) {
    parts.push(`الحقول: ${details.changed.join('، ')}`)
  }
  if (typeof details.audience === 'string') {
    parts.push(`الفئة: ${details.audience}`)
  }
  // عددُ من وصلتهم الحملة: «أُرسل إشعار» بلا عددٍ لا تُفرَّق عن «أُرسل إلى صفر»،
  // وهو الفرق بين حملةٍ عملت وحملةٍ سقطت في صمت.
  if (typeof details.recipients === 'number') {
    parts.push(`المستلمون: ${formatNumber(details.recipients)}`)
  }
  if (typeof details.amount === 'number') {
    parts.push(`المبلغ: ${formatMoney(details.amount)}`)
  }
  if (typeof details.user === 'string') {
    parts.push(`العميل: ${details.user}`)
  }
  if (typeof details.reason === 'string' && details.reason) {
    parts.push(`السبب: ${details.reason}`)
  }

  return parts.join(' · ')
}

function format(value: unknown): string {
  if (value === true) return 'مفعّل'
  if (value === false) return 'موقوف'
  if (value === null || value === undefined) return '—'
  return String(value)
}

export function AuditPage() {
  const [entity, setEntity] = useState<AuditQuery['entity']>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [confirmPurge, setConfirmPurge] = useState(false)
  const [purging, setPurging] = useState(false)
  const [purgeError, setPurgeError] = useState<string | null>(null)
  const { role } = useAuth()

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, entity])

  const load = useCallback(
    () => listAudit({ entity, search: debouncedSearch, page, pageSize: PAGE_SIZE }),
    [entity, debouncedSearch, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    entity,
    debouncedSearch,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const buildExport = useCallback(async () => {
    const all = await listAudit({
      entity,
      search: debouncedSearch,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: ['التاريخ', 'المسؤول', 'العملية', 'النوع', 'العنصر', 'التفاصيل'],
      rows: all.rows.map((entry) => [
        formatDateTime(entry.created_at),
        entry.actor_email,
        AUDIT_ACTION_LABEL[entry.action] ?? entry.action,
        AUDIT_ENTITY_LABEL[entry.entity] ?? entry.entity,
        entry.entity_label,
        describe(entry.details),
      ]),
    }
  }, [entity, debouncedSearch])

  function openPurge() {
    setPurgeError(null)
    setConfirmPurge(true)
  }

  async function handlePurge() {
    setPurging(true)
    setPurgeError(null)
    try {
      const removed = await clearAuditLog()
      setConfirmPurge(false)
      setPage(0)
      setToast(`فُرِّغ السجل — أُزيل ${removed} سجلّاً، وبقي أثر التفريغ نفسه.`)
      reload()
    } catch (cause) {
      // يبقى الحوار مفتوحاً حاملاً السبب: إغلاقه مع رسالةٍ في `Toast` يدفنها
      // تحت ستار النافذة، فيبدو الزر معطّلاً بلا تفسير.
      setPurgeError(errorText(cause, 'تعذّر تفريغ السجل.'))
    } finally {
      setPurging(false)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-56 flex-1">
          <Search
            size={15}
            aria-hidden
            className="pointer-events-none absolute top-1/2 start-3 -translate-y-1/2 text-muted"
          />
          <Input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="ابحث باسم المسؤول أو العنصر…"
            aria-label="بحث في سجل العمليات"
            className="ps-9"
          />
        </div>

        <div className="w-44">
          <Select
            value={entity}
            onChange={(event) => setEntity(event.target.value as AuditQuery['entity'])}
            aria-label="تصفية حسب النوع"
          >
            <option value="all">كل الأنواع</option>
            {Object.keys(AUDIT_ENTITY_LABEL).map((key) => (
              <option key={key} value={key}>
                {AUDIT_ENTITY_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <ExportButton
          filenamePrefix="سجل-العمليات"
          build={buildExport}
          disabled={!data || data.total === 0}
          onError={setToast}
        />

        {/* للمالك وحده — والقاعدة تتحقّق أيضاً، فإخفاؤه هنا راحةٌ لا حماية. */}
        {role === 'owner' ? (
          <Button
            variant="ghost"
            onClick={openPurge}
            disabled={!data || data.total === 0 || purging}
            className="text-[var(--critical)]"
          >
            <Trash2 size={15} aria-hidden />
            تفريغ السجل
          </Button>
        ) : null}
      </div>

      {!isSupabaseConfigured ? (
        <p className="glass-item rounded-lg px-3 py-2.5 text-xs leading-6 text-ink-2">
          في وضع العرض التجريبي يبدأ السجل فارغاً ويمتلئ بما تفعله الآن — جرّب إيقاف مستخدم أو
          تغيير إعداد ثم عُد إلى هنا. يُحفظ محلياً في متصفحك، ويُمسح عند تسجيل الخروج.
        </p>
      ) : null}

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState
            title="لا توجد عمليات مسجّلة"
            description="كل تعديل يقوم به المسؤولون سيظهر هنا تلقائياً."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {['التاريخ', 'المسؤول', 'العملية', 'العنصر', 'التفاصيل'].map((heading) => (
                    <th
                      key={heading}
                      scope="col"
                      className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((entry) => (
                  <tr key={entry.id} className="glass-row border-b border-hairline last:border-0">
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink">
                      {formatDateTime(entry.created_at)}
                    </td>
                    <td dir="ltr" className="px-4 py-3 text-start text-xs whitespace-nowrap text-ink-2">
                      {entry.actor_email || '—'}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink">
                      {AUDIT_ACTION_LABEL[entry.action] ?? entry.action}
                    </td>
                    <td className="px-4 py-3 text-xs text-ink-2">
                      <span className="text-muted">
                        {AUDIT_ENTITY_LABEL[entry.entity] ?? entry.entity}:{' '}
                      </span>
                      {entry.entity_label || '—'}
                    </td>
                    <td className="px-4 py-3 text-xs text-muted">{describe(entry.details) || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {data && data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
        ) : null}
      </Card>

      {toast ? <Toast message={toast} /> : null}

      <ConfirmDialog
        open={confirmPurge}
        title="تفريغ سجل العمليات؟"
        message={
          `سيُحذف ${data?.total ?? 0} سجلّاً حذفاً نهائياً لا رجعة فيه. ` +
          'ويبقى في السجل صفٌّ واحد يُثبت أنك فرّغته ومتى وكم أزلت — فالأثر لا يُمحى كلّه.'
        }
        confirmLabel="نعم، فرّغ السجل"
        busy={purging}
        error={purgeError}
        onConfirm={handlePurge}
        onCancel={() => setConfirmPurge(false)}
      />
    </div>
  )
}
