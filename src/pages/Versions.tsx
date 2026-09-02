import { useCallback, useEffect, useState } from 'react'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Input, Toggle } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { PLATFORM_LABEL, formatDate } from '@/lib/format'
import type { AppVersion } from '@/lib/types'
import {
  isDownloadUrlValid,
  listVersions,
  setDownloadUrl,
  setForceUpdate,
  setRollout,
} from '@/services/versions'
import { errorText } from '@/services/base'

export function VersionsPage() {
  const load = useCallback(() => listVersions(), [])
  const { data, error, loading, refetching, reload } = useAsync(load, [])
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  if (loading) return <LoadingBlock />
  if (error && !data) return <ErrorState message={error} onRetry={reload} />
  if (!data || data.length === 0) {
    return (
      <Card>
        <EmptyState
          title="لا توجد إصدارات مسجّلة"
          description="أضف صفوفاً إلى جدول app_versions لتظهر هنا."
        />
      </Card>
    )
  }

  return (
    <div className={cn('grid grid-cols-1 gap-4 lg:grid-cols-2', refetching && 'is-refetching')}>
      {data.map((version) => (
        <VersionCard key={version.id} version={version} onDone={setToast} onSaved={reload} />
      ))}

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function VersionCard({
  version,
  onDone,
  onSaved,
}: {
  version: AppVersion
  onDone: (message: string) => void
  onSaved: () => void
}) {
  const { can } = useAuth()
  const canWrite = can('ops')
  // The slider tracks locally while dragging and only commits on release, so a
  // drag from 60 to 100 is one write instead of nine.
  const [rollout, setRolloutValue] = useState(version.rollout_percent)
  const [url, setUrl] = useState(version.download_url)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    setRolloutValue(version.rollout_percent)
  }, [version.rollout_percent])

  useEffect(() => {
    setUrl(version.download_url)
  }, [version.download_url])

  const urlError =
    isDownloadUrlValid(url.trim()) ? null : 'يجب أن يبدأ بـ https:// — التطبيق يفتحه على جهاز صاحبه.'

  async function commit(action: () => Promise<void>, message: string) {
    setBusy(true)
    try {
      await action()
      onDone(message)
      onSaved()
    } catch (cause) {
      onDone(errorText(cause, 'تعذّر حفظ التغيير.'))
    } finally {
      setBusy(false)
    }
  }

  function commitRollout() {
    if (rollout === version.rollout_percent) return
    void commit(() => setRollout(version, rollout), 'تم تحديث نسبة الطرح.')
  }

  function commitUrl() {
    const trimmed = url.trim()
    if (trimmed === version.download_url || urlError) return
    void commit(() => setDownloadUrl(version, trimmed), 'تم حفظ رابط التنزيل.')
  }

  return (
    <Card>
      <CardHeader
        title={
          <span className="flex items-center gap-2">
            <span className="tnum" dir="ltr">
              {version.version}
            </span>
            <span className="text-xs font-normal text-muted">
              ({PLATFORM_LABEL[version.platform]} · بناء {version.build})
            </span>
          </span>
        }
        subtitle={`صدر في ${formatDate(version.released_at)}`}
        actions={
          // A version with no link reaches nobody, so "available to everyone"
          // would be a lie — and the lie is the dangerous kind: it reads as
          // shipped while the app silently skips the row.
          !version.download_url ? (
            <Badge tone="warning">بلا رابط</Badge>
          ) : version.force_update ? (
            <Badge tone="serious">تحديث إجباري</Badge>
          ) : version.rollout_percent < 100 ? (
            <Badge tone="warning">طرح تدريجي</Badge>
          ) : (
            <Badge tone="good">متاح للجميع</Badge>
          )
        }
      />
      <CardBody className="flex flex-col gap-4">
        <p className="text-xs leading-6 text-ink-2">{version.notes || 'لا توجد ملاحظات.'}</p>

        <Field
          label="رابط التنزيل"
          error={urlError}
          hint={
            version.download_url ? (
              <a
                href={version.download_url}
                target="_blank"
                rel="noreferrer noopener"
                className="text-accent underline underline-offset-2"
              >
                افتح الرابط للتأكّد منه
              </a>
            ) : (
              'بدون رابط لا يُعرض هذا الإصدار على أحد — ولو كان إجبارياً.'
            )
          }
        >
          {(id) => (
            <Input
              id={id}
              dir="ltr"
              inputMode="url"
              placeholder="https://…"
              value={url}
              disabled={busy || !canWrite}
              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
              onChange={(event) => setUrl(event.target.value)}
              onBlur={commitUrl}
              onKeyDown={(event) => {
                if (event.key === 'Enter') event.currentTarget.blur()
              }}
            />
          )}
        </Field>

        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between text-xs">
            <label htmlFor={`rollout-${version.id}`} className="font-medium text-ink-2">
              نسبة الطرح
            </label>
            <span className="tnum text-ink">{rollout}%</span>
          </div>
          <input
            id={`rollout-${version.id}`}
            type="range"
            min={0}
            max={100}
            step={5}
            value={rollout}
            disabled={busy || !canWrite}
            style={{ accentColor: 'var(--series-1)' }}
            className="w-full cursor-pointer disabled:cursor-not-allowed"
            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
            onChange={(event) => setRolloutValue(Number(event.target.value))}
            onPointerUp={commitRollout}
            onKeyUp={commitRollout}
            onBlur={commitRollout}
          />
        </div>

        <Toggle
          checked={version.force_update}
          disabled={busy || !canWrite}
          onChange={(next) =>
            void commit(
              () => setForceUpdate(version, next),
              next ? 'تم تفعيل التحديث الإجباري.' : 'تم إلغاء التحديث الإجباري.',
            )
          }
          label="تحديث إجباري"
          description="يمنع استخدام التطبيق قبل التحديث إلى هذا الإصدار."
        />
      </CardBody>
    </Card>
  )
}
