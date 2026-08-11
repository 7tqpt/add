import { useCallback, useEffect, useState } from 'react'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { Badge } from '@/components/ui/Badge'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Toggle } from '@/components/ui/Field'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { PLATFORM_LABEL, formatDate } from '@/lib/format'
import type { AppVersion } from '@/lib/types'
import { listVersions, setForceUpdate, setRollout } from '@/services/versions'

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
  // The slider tracks locally while dragging and only commits on release, so a
  // drag from 60 to 100 is one write instead of nine.
  const [rollout, setRolloutValue] = useState(version.rollout_percent)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    setRolloutValue(version.rollout_percent)
  }, [version.rollout_percent])

  async function commit(action: () => Promise<void>, message: string) {
    setBusy(true)
    try {
      await action()
      onDone(message)
      onSaved()
    } catch (cause) {
      onDone(cause instanceof Error ? cause.message : 'تعذّر حفظ التغيير.')
    } finally {
      setBusy(false)
    }
  }

  function commitRollout() {
    if (rollout === version.rollout_percent) return
    void commit(() => setRollout(version.id, rollout), 'تم تحديث نسبة الطرح.')
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
          version.force_update ? (
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
            disabled={busy}
            style={{ accentColor: 'var(--series-1)' }}
            className="w-full cursor-pointer disabled:cursor-not-allowed"
            onChange={(event) => setRolloutValue(Number(event.target.value))}
            onPointerUp={commitRollout}
            onKeyUp={commitRollout}
            onBlur={commitRollout}
          />
        </div>

        <Toggle
          checked={version.force_update}
          disabled={busy}
          onChange={(next) =>
            void commit(
              () => setForceUpdate(version.id, next),
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
