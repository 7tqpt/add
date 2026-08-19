import { useCallback, useState } from 'react'
import { Link } from 'react-router-dom'
import { Check, Eye, X } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { Field, Textarea } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate } from '@/lib/format'
import type { ProviderStatus, ServiceProvider } from '@/lib/types'
import { PROVIDER_STATUS_LABEL, listProviders, setProviderStatus } from '@/services/directory'

type Tab = 'pending' | 'verified' | 'all'

const TABS: { value: Tab; label: string; status: ProviderStatus | 'all' }[] = [
  { value: 'pending', label: 'المعلّقة', status: 'pending' },
  { value: 'verified', label: 'الموثّقون', status: 'verified' },
  { value: 'all', label: 'الكل', status: 'all' },
]

/**
 * Verification decisions, taken where they are noticed.
 *
 * The document makes manual review the gate against fictitious vendors, so the
 * dashboard puts accept/reject on the home screen instead of behind two clicks —
 * but rejection still asks for a reason, which reaches the applicant.
 */
export function ProviderQueue() {
  const { can } = useAuth()
  const canWrite = can('directory')
  const [tab, setTab] = useState<Tab>('pending')
  const [pending, setPending] = useState<{ row: ServiceProvider; next: ProviderStatus } | null>(null)
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState<string | null>(null)

  const status = TABS.find((entry) => entry.value === tab)?.status ?? 'pending'

  const load = useCallback(
    () =>
      listProviders({
        search: '',
        status,
        category: 'all',
        governorate: 'all',
        page: 0,
        pageSize: 5,
      }),
    [status],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [status])

  async function decide() {
    if (!pending) return
    setBusy(true)
    try {
      await setProviderStatus(pending.row, pending.next, reason.trim())
      reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusy(false)
      setPending(null)
      setReason('')
    }
  }

  return (
    <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
      <CardHeader
        title="طلبات انضمام مقدّمي الخدمة"
        subtitle="المراجعة اليدوية هي ما يمنع تسجيل كيانات وهمية أو غير معتمدة محلياً"
        actions={
          <div role="tablist" aria-label="تصفية الطلبات" className="flex gap-1">
            {TABS.map((entry) => (
              <button
                key={entry.value}
                type="button"
                role="tab"
                aria-selected={tab === entry.value}
                onClick={() => setTab(entry.value)}
                className={cn(
                  'h-7 cursor-pointer rounded-md px-2.5 text-[11px] font-medium transition-colors',
                  tab === entry.value
                    ? 'bg-accent text-accent-ink'
                    : 'text-muted hover:bg-surface-2 hover:text-ink',
                )}
              >
                {entry.label}
              </button>
            ))}
          </div>
        }
      />

      {loading ? (
        <LoadingBlock />
      ) : error && !data ? (
        <ErrorState message={error} onRetry={reload} />
      ) : !data || data.rows.length === 0 ? (
        <EmptyState
          title="لا توجد طلبات"
          description={tab === 'pending' ? 'كل الطلبات مُراجَعة.' : 'لا نتائج في هذا التصنيف.'}
        />
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-xs">
            <thead>
              <tr className="glass-item">
                {['المزوّد', 'الأقسام', 'الموقع', 'الحالة', ''].map(
                  (heading, index) => (
                    <th
                      key={index}
                      scope="col"
                      className="border-b border-hairline px-4 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ),
                )}
              </tr>
            </thead>
            <tbody>
              {data.rows.map((provider) => (
                <tr
                  key={provider.id}
                  className="glass-row border-b border-hairline last:border-0"
                >
                  <td className="px-4 py-2.5">
                    <Link
                      to={`/providers/${provider.id}`}
                      className="font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                    >
                      {provider.business_name || provider.full_name}
                    </Link>
                    <p className="text-[11px] text-muted">
                      تاريخ التقديم: {formatDate(provider.applied_at)}
                    </p>
                  </td>
                  <td className="px-4 py-2.5 text-ink-2">{provider.categories.join('، ') || '—'}</td>
                  <td className="px-4 py-2.5 whitespace-nowrap text-ink-2">
                    {provider.governorate}
                  </td>
                  <td className="px-4 py-2.5">
                    <Badge
                      tone={
                        provider.status === 'verified'
                          ? 'good'
                          : provider.status === 'pending'
                            ? 'warning'
                            : provider.status === 'suspended'
                              ? 'critical'
                              : 'neutral'
                      }
                    >
                      {PROVIDER_STATUS_LABEL[provider.status]}
                    </Badge>
                  </td>
                  <td className="px-4 py-2.5">
                    <div className="flex items-center justify-end gap-1.5">
                      <Link
                        to={`/providers/${provider.id}`}
                        aria-label={`عرض ملف ${provider.business_name}`}
                        title="عرض الملف والمستندات"
                        className="rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-ink"
                      >
                        <Eye size={14} aria-hidden />
                      </Link>
                      {provider.status === 'pending' ? (
                        <>
                          <Button
                            size="sm"
                            variant="primary"
                            disabled={busy || !canWrite}
                            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                            onClick={() => setPending({ row: provider, next: 'verified' })}
                          >
                            <Check size={13} aria-hidden />
                            قبول
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy || !canWrite}
                            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                            onClick={() => setPending({ row: provider, next: 'rejected' })}
                          >
                            <X size={13} aria-hidden />
                            رفض
                          </Button>
                        </>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <ConfirmDialog
        open={pending !== null}
        title={pending?.next === 'verified' ? 'توثيق مقدّم الخدمة؟' : 'رفض الطلب؟'}
        message={
          pending?.next === 'verified'
            ? `سيتمكّن ${pending.row.business_name || pending.row.full_name} من استقبال الحجوزات فوراً. راجع المستندات من صفحته إن لم تفعل بعد.`
            : `سيُرفض طلب ${pending?.row.business_name ?? ''} ولن يظهر للعملاء. يمكنك إعادته للمراجعة لاحقاً.`
        }
        confirmLabel={pending?.next === 'verified' ? 'توثيق' : 'رفض'}
        tone={pending?.next === 'verified' ? 'primary' : 'danger'}
        busy={busy}
        onConfirm={decide}
        onCancel={() => {
          setPending(null)
          setReason('')
        }}
      >
        {pending?.next === 'rejected' ? (
          <Field label="سبب الرفض" hint="يظهر لمقدّم الخدمة وفي سجل العمليات.">
            {(fieldId) => (
              <Textarea
                id={fieldId}
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                placeholder="مثال: السجل التجاري غير واضح، يرجى إعادة الرفع."
              />
            )}
          </Field>
        ) : null}
      </ConfirmDialog>

      {toast ? (
        <p role="alert" className="px-4 py-2 text-xs text-[var(--critical)]">
          {toast}
        </p>
      ) : null}
    </Card>
  )
}
