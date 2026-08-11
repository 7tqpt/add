import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Eye, EyeOff, Search } from 'lucide-react'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { Rating } from '@/components/ui/Rating'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatRelative } from '@/lib/format'
import type { Review, ReviewStatus } from '@/lib/types'
import { REVIEW_STATUS_LABEL, listReviews, setReviewStatus } from '@/services/trust'

const PAGE_SIZE = 10

const STATUS_TONE: Record<ReviewStatus, Tone> = {
  published: 'good',
  hidden: 'neutral',
  flagged: 'serious',
}

export function ReviewsPage() {
  const { canWrite } = useAuth()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<ReviewStatus | 'all'>('all')
  const [rating, setRating] = useState<number | 'all'>('all')
  const [page, setPage] = useState(0)
  const [toast, setToast] = useState<string | null>(null)
  const [hiding, setHiding] = useState<Review | null>(null)
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)

  const debouncedSearch = useDebounced(search)

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, status, rating])

  const load = useCallback(
    () => listReviews({ search: debouncedSearch, status, rating, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, status, rating, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    status,
    rating,
    page,
  ])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function run(review: Review, next: ReviewStatus, note: string, message: string) {
    setBusy(true)
    try {
      await setReviewStatus(review, next, note)
      setToast(message)
      reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusy(false)
      setHiding(null)
      setReason('')
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
            placeholder="ابحث بنص التقييم أو أحد الطرفين…"
            aria-label="بحث في التقييمات"
            className="ps-9"
          />
        </div>

        <div className="w-40">
          <Select
            value={status}
            onChange={(event) => setStatus(event.target.value as ReviewStatus | 'all')}
            aria-label="تصفية حسب الحالة"
          >
            <option value="all">كل الحالات</option>
            {(Object.keys(REVIEW_STATUS_LABEL) as ReviewStatus[]).map((key) => (
              <option key={key} value={key}>
                {REVIEW_STATUS_LABEL[key]}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-36">
          <Select
            value={String(rating)}
            onChange={(event) =>
              setRating(event.target.value === 'all' ? 'all' : Number(event.target.value))
            }
            aria-label="تصفية حسب النجوم"
          >
            <option value="all">كل التقييمات</option>
            {[5, 4, 3, 2, 1].map((value) => (
              <option key={value} value={value}>
                {value} نجوم
              </option>
            ))}
          </Select>
        </div>
      </div>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState
            title="لا توجد تقييمات"
            description="جرّب تعديل البحث أو إزالة عوامل التصفية."
          />
        ) : (
          <ul className="divide-y divide-[var(--border)]">
            {data.rows.map((review) => (
              <li key={review.id} className="flex flex-col gap-2 px-4 py-3.5 sm:px-5">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2.5">
                    <Rating value={review.rating} />
                    <span className="text-xs text-ink-2">
                      {review.user_name} ←{' '}
                      <Link
                        to={`/providers/${review.provider_id}`}
                        className="font-medium text-ink underline-offset-4 hover:text-accent hover:underline"
                      >
                        {review.provider_name}
                      </Link>
                    </span>
                    <Badge tone={STATUS_TONE[review.status]}>
                      {REVIEW_STATUS_LABEL[review.status]}
                    </Badge>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <Link
                      to={`/bookings/${review.booking_id}`}
                      dir="ltr"
                      className="tnum text-[11px] text-muted underline-offset-4 hover:text-accent hover:underline"
                    >
                      {review.booking_reference}
                    </Link>
                    {review.status === 'hidden' ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={busy || !canWrite}
                        title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                        onClick={() => run(review, 'published', '', 'أُعيد نشر التقييم.')}
                      >
                        <Eye size={14} aria-hidden />
                        إعادة النشر
                      </Button>
                    ) : (
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={busy || !canWrite}
                        title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                        onClick={() => setHiding(review)}
                      >
                        <EyeOff size={14} aria-hidden />
                        إخفاء
                      </Button>
                    )}
                  </div>
                </div>

                <p className="text-xs leading-6 text-ink-2">{review.comment || '— بلا تعليق —'}</p>

                <div className="flex flex-wrap items-center gap-2 text-[11px] text-muted">
                  <span>{formatRelative(review.created_at)}</span>
                  {review.hidden_reason ? <span>· سبب الإخفاء: {review.hidden_reason}</span> : null}
                </div>
              </li>
            ))}
          </ul>
        )}

        {data && data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
        ) : null}
      </Card>

      <ConfirmDialog
        open={hiding !== null}
        title="إخفاء هذا التقييم؟"
        message="لن يظهر التقييم للعملاء ولن يُحتسب ضمن متوسط مقدّم الخدمة، لكنه يبقى محفوظاً في السجل."
        confirmLabel="إخفاء"
        busy={busy}
        onConfirm={() =>
          hiding && run(hiding, 'hidden', reason.trim(), 'أُخفي التقييم.')
        }
        onCancel={() => {
          setHiding(null)
          setReason('')
        }}
      >
        <Field label="سبب الإخفاء" hint="يظهر في سجل العمليات فقط، لا للعميل.">
          {(fieldId) => (
            <Textarea
              id={fieldId}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="مثال: لغة مسيئة لا تتعلق بالخدمة."
            />
          )}
        </Field>
      </ConfirmDialog>

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}
