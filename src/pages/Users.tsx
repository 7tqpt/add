import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search, UserCheck, UserX } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
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
import { PLATFORM_LABEL, formatDate, formatNumber, formatRelative } from '@/lib/format'
import type { AppUser, Platform, UserStatus } from '@/lib/types'
import { USER_STATUS_LABEL, listUsers, updateUserStatus } from '@/services/users'

const PAGE_SIZE = 10
/** Upper bound on a single CSV export, so a huge table cannot hang the browser. */
const EXPORT_LIMIT = 5000

const STATUS_TONE: Record<UserStatus, Tone> = {
  active: 'good',
  suspended: 'critical',
  pending: 'warning',
}

export function UsersPage() {
  const { canWrite } = useAuth()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<UserStatus | 'all'>('all')
  const [platform, setPlatform] = useState<Platform | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [pending, setPending] = useState<AppUser | null>(null)
  const [busy, setBusy] = useState(false)

  const debouncedSearch = useDebounced(search)

  // Any filter change invalidates the current offset — page 3 of the old result
  // set is meaningless against the new one.
  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, platform])

  const load = useCallback(
    () => listUsers({ search: debouncedSearch, status, platform, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, platform, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    platform,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function applyStatus(user: AppUser, next: UserStatus) {
    setBusy(true)
    try {
      await updateUserStatus(user, next)
      setToast(next === 'suspended' ? 'تم إيقاف المستخدم.' : 'تم تفعيل المستخدم.')
      reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث الحالة.')
    } finally {
      setBusy(false)
      setPending(null)
    }
  }

  // Suspending cuts a real person off from the app, so it asks first.
  // Re-activating is not destructive and applies immediately.
  function requestToggle(user: AppUser) {
    if (user.status === 'suspended') void applyStatus(user, 'active')
    else setPending(user)
  }

  const buildExport = useCallback(async () => {
    const all = await listUsers({
      search: debouncedSearch,
      status,
      platform,
      page: 0,
      pageSize: EXPORT_LIMIT,
    })
    return {
      columns: ['الاسم', 'البريد', 'الجوال', 'المنصة', 'الدولة', 'الإصدار', 'الجلسات', 'الحالة', 'تاريخ التسجيل', 'آخر ظهور'],
      rows: all.rows.map((user) => [
        user.full_name,
        user.email,
        user.phone ?? '',
        PLATFORM_LABEL[user.platform],
        user.country,
        user.app_version,
        user.sessions_count,
        USER_STATUS_LABEL[user.status],
        formatDate(user.created_at),
        user.last_seen_at ? formatDate(user.last_seen_at) : '',
      ]),
    }
  }, [debouncedSearch, status, platform])

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
            placeholder="ابحث بالاسم أو البريد أو الجوال…"
            aria-label="بحث في المستخدمين"
            className="ps-9"
          />
        </div>

        {/* Controls are w-full by default, so the width lives on the wrapper. */}
        <div className="w-44">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as UserStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            <option value="active">{USER_STATUS_LABEL.active}</option>
            <option value="pending">{USER_STATUS_LABEL.pending}</option>
            <option value="suspended">{USER_STATUS_LABEL.suspended}</option>
          </Select>
        </div>

        <div className="w-36">
          <Select
            value={platform}
            onChange={(event) => setPlatform(event.target.value as Platform | 'all')}
            aria-label="تصفية حسب المنصة"
          >
            <option value="all">كل المنصات</option>
            <option value="ios">{PLATFORM_LABEL.ios}</option>
            <option value="android">{PLATFORM_LABEL.android}</option>
          </Select>
        </div>

        <ExportButton
          filenamePrefix="تقرير-المستخدمين"
          build={buildExport}
          disabled={!data || data.total === 0}
          onError={setToast}
        />
      </div>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState
            title="لا توجد نتائج"
            description="جرّب تعديل كلمات البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {['المستخدم', 'المنصة', 'الإصدار', 'الدولة', 'الجلسات', 'آخر ظهور', 'الحالة', ''].map(
                    (heading, index) => (
                      <th
                        key={index}
                        scope="col"
                        className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                      >
                        {heading}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody>
                {data.rows.map((user) => (
                  <tr key={user.id} className="border-b border-hairline last:border-0 hover:bg-surface-2">
                    <td className="px-4 py-3">
                      <Link
                        to={`/users/${user.id}`}
                        className="font-medium text-ink underline-offset-4 hover:text-series-1 hover:underline"
                      >
                        {user.full_name}
                      </Link>
                      <p dir="ltr" className="text-start text-xs text-muted">
                        {user.email}
                      </p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {PLATFORM_LABEL[user.platform]}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {user.app_version || '—'}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">{user.country || '—'}</td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatNumber(user.sessions_count)}
                    </td>
                    <td
                      className="px-4 py-3 text-xs whitespace-nowrap text-ink-2"
                      title={user.last_seen_at ? formatDate(user.last_seen_at) : undefined}
                    >
                      {formatRelative(user.last_seen_at)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge tone={STATUS_TONE[user.status]}>{USER_STATUS_LABEL[user.status]}</Badge>
                    </td>
                    <td className="px-4 py-3 text-end">
                      <Button
                        size="sm"
                        variant={user.status === 'suspended' ? 'secondary' : 'ghost'}
                        disabled={busy || !canWrite}
                        title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                        onClick={() => requestToggle(user)}
                      >
                        {user.status === 'suspended' ? (
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
                    </td>
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

      <ConfirmDialog
        open={pending !== null}
        title="إيقاف المستخدم؟"
        message={
          pending
            ? `سيفقد ${pending.full_name} إمكانية استخدام التطبيق فوراً حتى يُعاد تفعيل حسابه. سيُسجَّل هذا الإجراء باسمك في سجل العمليات.`
            : ''
        }
        confirmLabel="إيقاف الحساب"
        busy={busy}
        onConfirm={() => pending && applyStatus(pending, 'suspended')}
        onCancel={() => setPending(null)}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
