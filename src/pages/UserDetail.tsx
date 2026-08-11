import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  Activity,
  ArrowRight,
  BellOff,
  BellRing,
  Clock,
  Smartphone,
  UserCheck,
  UserX,
  Wallet,
} from 'lucide-react'
import { StatTile } from '@/components/charts/StatTile'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import {
  PLATFORM_LABEL,
  formatDate,
  formatDateTime,
  formatDuration,
  formatMoney,
  formatNumber,
  formatRelative,
} from '@/lib/format'
import type { AppUser, PurchaseStatus, UserStatus } from '@/lib/types'
import { PURCHASE_STATUS_LABEL, getUserActivity } from '@/services/userActivity'
import { USER_STATUS_LABEL, getUser, updateUserStatus } from '@/services/users'

const STATUS_TONE: Record<UserStatus, Tone> = {
  active: 'good',
  suspended: 'critical',
  pending: 'warning',
}

const PURCHASE_TONE: Record<PurchaseStatus, Tone> = {
  paid: 'good',
  refunded: 'warning',
  failed: 'critical',
  pending: 'neutral',
}

export function UserDetailPage() {
  const { id = '' } = useParams()
  const { canWrite } = useAuth()
  const [toast, setToast] = useState<string | null>(null)
  const [confirming, setConfirming] = useState(false)
  const [busy, setBusy] = useState(false)

  const loadUser = useCallback(() => getUser(id), [id])
  const loadActivity = useCallback(() => getUserActivity(id), [id])

  const user = useAsync(loadUser, [id])
  const activity = useAsync(loadActivity, [id])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function applyStatus(target: AppUser, next: UserStatus) {
    setBusy(true)
    try {
      await updateUserStatus(target, next)
      setToast(next === 'suspended' ? 'تم إيقاف المستخدم.' : 'تم تفعيل المستخدم.')
      user.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث الحالة.')
    } finally {
      setBusy(false)
      setConfirming(false)
    }
  }

  if (user.loading) return <LoadingBlock />
  if (user.error && !user.data) return <ErrorState message={user.error} onRetry={user.reload} />
  if (!user.data) {
    return (
      <Card>
        <EmptyState
          title="المستخدم غير موجود"
          description="ربما حُذف الحساب أو أن الرابط غير صحيح."
          action={
            <Link to="/users" className="text-sm font-medium text-series-1 underline underline-offset-4">
              العودة إلى قائمة المستخدمين
            </Link>
          }
        />
      </Card>
    )
  }

  const record = user.data
  const sessions = activity.data?.sessions ?? []
  const devices = activity.data?.devices ?? []
  const purchases = activity.data?.purchases ?? []

  const paid = purchases.filter((purchase) => purchase.status === 'paid')
  const totalSpent = paid.reduce((sum, purchase) => sum + purchase.amount, 0)
  const averageSession = sessions.length
    ? sessions.reduce((sum, session) => sum + session.duration_seconds, 0) / sessions.length
    : 0

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/users"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        {/* Under RTL "back" points toward the start edge, which is the right. */}
        <ArrowRight size={14} aria-hidden />
        كل المستخدمين
      </Link>

      <Card>
        <CardHeader
          title={record.full_name}
          subtitle={record.email}
          actions={
            <div className="flex items-center gap-2">
              <Badge tone={STATUS_TONE[record.status]}>{USER_STATUS_LABEL[record.status]}</Badge>
              <Button
                size="sm"
                variant={record.status === 'suspended' ? 'secondary' : 'ghost'}
                disabled={busy || !canWrite}
                title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                onClick={() =>
                  record.status === 'suspended' ? applyStatus(record, 'active') : setConfirming(true)
                }
              >
                {record.status === 'suspended' ? (
                  <>
                    <UserCheck size={14} aria-hidden />
                    تفعيل
                  </>
                ) : (
                  <>
                    <UserX size={14} aria-hidden />
                    إيقاف
                  </>
                )}
              </Button>
            </div>
          }
        />
        <CardBody>
          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-6">
            <Detail label="الجوال" value={record.phone ?? '—'} ltr />
            <Detail label="المنصة" value={PLATFORM_LABEL[record.platform]} />
            <Detail label="الدولة" value={record.country || '—'} />
            <Detail label="إصدار التطبيق" value={record.app_version || '—'} ltr />
            <Detail label="تاريخ التسجيل" value={formatDate(record.created_at)} />
            <Detail label="آخر ظهور" value={formatRelative(record.last_seen_at)} />
          </dl>
        </CardBody>
      </Card>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile
          label="إجمالي الجلسات"
          value={formatNumber(record.sessions_count)}
          icon={Activity}
          refetching={activity.refetching}
        />
        <StatTile
          label="متوسط مدة الجلسة"
          value={formatDuration(averageSession)}
          icon={Clock}
          refetching={activity.refetching}
        />
        <StatTile
          label="إجمالي المدفوعات"
          value={formatMoney(totalSpent)}
          icon={Wallet}
          refetching={activity.refetching}
        />
      </div>

      {activity.loading ? (
        <Card>
          <LoadingBlock />
        </Card>
      ) : activity.error && !activity.data ? (
        <Card>
          <ErrorState message={activity.error} onRetry={activity.reload} />
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
            <div className="xl:col-span-2">
              <Card className="overflow-hidden">
                <CardHeader title="آخر الجلسات" subtitle="أحدث 20 جلسة" />
                {sessions.length === 0 ? (
                  <EmptyState title="لا توجد جلسات مسجّلة" />
                ) : (
                  <div className="max-h-96 overflow-auto">
                    <table className="w-full border-collapse text-xs">
                      <thead className="sticky top-0 bg-surface-2">
                        <tr>
                          {['بدأت في', 'المدة', 'المنصة', 'الإصدار', 'الدولة'].map((heading) => (
                            <th
                              key={heading}
                              scope="col"
                              className="border-b border-hairline px-4 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                            >
                              {heading}
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {sessions.map((session) => (
                          <tr key={session.id} className="border-b border-hairline last:border-0">
                            <td className="tnum px-4 py-2 whitespace-nowrap text-ink">
                              {formatDateTime(session.started_at)}
                            </td>
                            <td className="tnum px-4 py-2 whitespace-nowrap text-ink-2">
                              {formatDuration(session.duration_seconds)}
                            </td>
                            <td className="px-4 py-2 whitespace-nowrap text-ink-2">
                              {PLATFORM_LABEL[session.platform]}
                            </td>
                            <td className="tnum px-4 py-2 whitespace-nowrap text-ink-2">
                              {session.app_version || '—'}
                            </td>
                            <td className="px-4 py-2 whitespace-nowrap text-ink-2">
                              {session.country || '—'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </Card>
            </div>

            <Card>
              <CardHeader title="الأجهزة" subtitle={`${formatNumber(devices.length)} جهاز مسجّل`} />
              {devices.length === 0 ? (
                <EmptyState title="لا توجد أجهزة مسجّلة" />
              ) : (
                <ul className="divide-y divide-[var(--border)]">
                  {devices.map((device) => (
                    <li key={device.id} className="flex items-start gap-3 px-4 py-3 sm:px-5">
                      <Smartphone size={16} aria-hidden className="mt-0.5 shrink-0 text-muted" />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium text-ink">{device.model}</p>
                        <p className="mt-0.5 text-[11px] text-muted">
                          {PLATFORM_LABEL[device.platform]} {device.os_version} · آخر استخدام{' '}
                          {formatRelative(device.last_used_at)}
                        </p>
                      </div>
                      {/* Icon + text, never the icon alone. */}
                      <span
                        className="flex shrink-0 items-center gap-1 text-[11px] text-ink-2"
                        title={device.push_enabled ? 'الإشعارات مفعّلة' : 'الإشعارات موقوفة'}
                      >
                        {device.push_enabled ? (
                          <BellRing size={13} aria-hidden />
                        ) : (
                          <BellOff size={13} aria-hidden />
                        )}
                        {device.push_enabled ? 'مفعّلة' : 'موقوفة'}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>

          <Card className="overflow-hidden">
            <CardHeader
              title="المشتريات"
              subtitle={`${formatNumber(purchases.length)} عملية · ${formatNumber(paid.length)} مدفوعة`}
            />
            {purchases.length === 0 ? (
              <EmptyState title="لا توجد مشتريات" />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-xs">
                  <thead>
                    <tr className="bg-surface-2">
                      {['المنتج', 'المبلغ', 'الحالة', 'التاريخ'].map((heading) => (
                        <th
                          key={heading}
                          scope="col"
                          className="border-b border-hairline px-4 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                        >
                          {heading}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {purchases.map((purchase) => (
                      <tr key={purchase.id} className="border-b border-hairline last:border-0">
                        <td className="px-4 py-2.5 whitespace-nowrap text-ink">{purchase.product}</td>
                        <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                          {formatMoney(purchase.amount)}
                        </td>
                        <td className="px-4 py-2.5">
                          <Badge tone={PURCHASE_TONE[purchase.status]}>
                            {PURCHASE_STATUS_LABEL[purchase.status]}
                          </Badge>
                        </td>
                        <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                          {formatDate(purchase.created_at)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </>
      )}

      <ConfirmDialog
        open={confirming}
        title="إيقاف المستخدم؟"
        message={`سيفقد ${record.full_name} إمكانية استخدام التطبيق فوراً حتى يُعاد تفعيل حسابه. سيُسجَّل هذا الإجراء باسمك في سجل العمليات.`}
        confirmLabel="إيقاف الحساب"
        busy={busy}
        onConfirm={() => applyStatus(record, 'suspended')}
        onCancel={() => setConfirming(false)}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function Detail({ label, value, ltr }: { label: string; value: string; ltr?: boolean }) {
  return (
    <div className="min-w-0">
      <dt className="text-muted">{label}</dt>
      <dd
        dir={ltr ? 'ltr' : undefined}
        className={`mt-0.5 truncate font-medium text-ink ${ltr ? 'text-start' : ''}`}
      >
        {value}
      </dd>
    </div>
  )
}
