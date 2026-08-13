import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Send } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ExportButton } from '@/components/ui/ExportButton'
import { EmptyState, ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatDateTime, formatNumber, formatPercent } from '@/lib/format'
import type { Audience, NotificationStatus } from '@/lib/types'
import {
  AUDIENCE_LABEL,
  NOTIFICATION_STATUS_LABEL,
  createNotification,
  listNotifications,
} from '@/services/notifications'

const STATUS_TONE: Record<NotificationStatus, Tone> = {
  sent: 'good',
  scheduled: 'warning',
  draft: 'neutral',
  failed: 'critical',
}

const TITLE_LIMIT = 60
const BODY_LIMIT = 180

const PAGE_SIZE = 8
const EXPORT_LIMIT = 5000

export function NotificationsPage() {
  const { can } = useAuth()
  const canWrite = can('ops')
  const [page, setPage] = useState(0)
  const load = useCallback(() => listNotifications(page, PAGE_SIZE), [page])
  const { data, error, loading, refetching, reload } = useAsync(load, [page])

  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [audience, setAudience] = useState<Audience>('all')
  const [scheduled, setScheduled] = useState(false)
  const [scheduledAt, setScheduledAt] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setFormError(null)

    if (scheduled && !scheduledAt) {
      setFormError('اختر موعد الإرسال أو ألغِ الجدولة.')
      return
    }
    if (scheduled && new Date(scheduledAt).getTime() <= Date.now()) {
      setFormError('موعد الجدولة يجب أن يكون في المستقبل.')
      return
    }

    setSubmitting(true)
    try {
      await createNotification({
        title: title.trim(),
        body: body.trim(),
        audience,
        // datetime-local has no timezone; the browser parses it as local time.
        scheduledAt: scheduled ? new Date(scheduledAt).toISOString() : null,
      })
      setTitle('')
      setBody('')
      setScheduled(false)
      setScheduledAt('')
      setToast(scheduled ? 'تمت جدولة الإشعار.' : 'تم إرسال الإشعار.')
      // A new notification lands at the top, so jump back to the first page.
      if (page === 0) reload()
      else setPage(0)
    } catch (cause) {
      setFormError(cause instanceof Error ? cause.message : 'تعذّر إرسال الإشعار.')
    } finally {
      setSubmitting(false)
    }
  }

  const buildExport = useCallback(async () => {
    const all = await listNotifications(0, EXPORT_LIMIT)
    return {
      columns: ['العنوان', 'النص', 'الفئة', 'الحالة', 'الموعد', 'المستلمون', 'الفتحات'],
      rows: all.rows.map((notification) => [
        notification.title,
        notification.body,
        AUDIENCE_LABEL[notification.audience],
        NOTIFICATION_STATUS_LABEL[notification.status],
        notification.sent_at
          ? formatDate(notification.sent_at)
          : notification.scheduled_at
            ? formatDate(notification.scheduled_at)
            : '',
        notification.recipients,
        notification.opened,
      ]),
    }
  }, [])

  return (
    <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
      <Card className="h-fit">
        <CardHeader title="إشعار جديد" subtitle="اكتب الرسالة واختر الفئة المستهدفة" />
        <CardBody>
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            <Field label="العنوان" hint={`${title.length} / ${TITLE_LIMIT} حرف`}>
              {(id) => (
                <Input
                  id={id}
                  required
                  maxLength={TITLE_LIMIT}
                  value={title}
                  onChange={(event) => setTitle(event.target.value)}
                  placeholder="مثال: خصم 25% لنهاية الأسبوع"
                />
              )}
            </Field>

            <Field label="نص الرسالة" hint={`${body.length} / ${BODY_LIMIT} حرف`}>
              {(id) => (
                <Textarea
                  id={id}
                  required
                  maxLength={BODY_LIMIT}
                  value={body}
                  onChange={(event) => setBody(event.target.value)}
                  placeholder="اكتب نص الإشعار كما سيظهر على جهاز المستخدم…"
                />
              )}
            </Field>

            <Field label="الفئة المستهدفة">
              {(id) => (
                <Select
                  id={id}
                  value={audience}
                  onChange={(event) => setAudience(event.target.value as Audience)}
                >
                  {(Object.keys(AUDIENCE_LABEL) as Audience[]).map((key) => (
                    <option key={key} value={key}>
                      {AUDIENCE_LABEL[key]}
                    </option>
                  ))}
                </Select>
              )}
            </Field>

            <Toggle
              checked={scheduled}
              onChange={setScheduled}
              label="جدولة الإرسال"
              description="أرسل الإشعار في وقت محدد بدلاً من الآن."
            />

            {scheduled ? (
              <Field label="موعد الإرسال">
                {(id) => (
                  <Input
                    id={id}
                    type="datetime-local"
                    value={scheduledAt}
                    onChange={(event) => setScheduledAt(event.target.value)}
                  />
                )}
              </Field>
            ) : null}

            {formError ? (
              <p role="alert" className="text-xs text-[var(--critical)]">
                {formError}
              </p>
            ) : null}

            <Button
              type="submit"
              variant="primary"
              disabled={submitting || !canWrite}
              title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
            >
              {submitting ? <Spinner /> : <Send size={15} aria-hidden />}
              {scheduled ? 'جدولة الإشعار' : 'إرسال الآن'}
            </Button>
          </form>
        </CardBody>
      </Card>

      <div className="xl:col-span-2">
        <Card className={cn(refetching && 'is-refetching')}>
          <CardHeader
            title="سجل الإشعارات"
            subtitle="آخر الإشعارات المرسلة والمجدولة"
            actions={
              <ExportButton
                filenamePrefix="تقرير-الإشعارات"
                build={buildExport}
                disabled={!data || data.total === 0}
                onError={setToast}
              />
            }
          />

          {loading ? (
            <LoadingBlock />
          ) : error && !data ? (
            <ErrorState message={error} onRetry={reload} />
          ) : !data || data.rows.length === 0 ? (
            <EmptyState title="لا توجد إشعارات بعد" description="أرسل أول إشعار من النموذج المجاور." />
          ) : (
            <ul className="divide-y divide-[var(--border)]">
              {data.rows.map((notification) => {
                const openRate =
                  notification.recipients > 0 ? notification.opened / notification.recipients : null
                const stamp = notification.sent_at ?? notification.scheduled_at
                return (
                  <li key={notification.id} className="flex flex-col gap-2 px-4 py-3.5 sm:px-5">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <p className="text-sm font-medium text-ink">{notification.title}</p>
                      <Badge tone={STATUS_TONE[notification.status]}>
                        {NOTIFICATION_STATUS_LABEL[notification.status]}
                      </Badge>
                    </div>

                    <p className="text-xs leading-6 text-ink-2">{notification.body}</p>

                    <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[11px] text-muted">
                      <span>{AUDIENCE_LABEL[notification.audience]}</span>
                      {stamp ? <span className="tnum">{formatDateTime(stamp)}</span> : null}
                      {notification.recipients > 0 ? (
                        <span className="tnum">
                          {formatNumber(notification.recipients)} مستلم
                        </span>
                      ) : null}
                      {openRate !== null ? (
                        <span className="tnum">نسبة الفتح {formatPercent(openRate)}</span>
                      ) : null}
                    </div>
                  </li>
                )
              })}
            </ul>
          )}

          {data && data.rows.length > 0 ? (
            <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
          ) : null}
        </Card>
      </div>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
