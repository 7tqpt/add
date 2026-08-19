import { useCallback } from 'react'
import { Link } from 'react-router-dom'
import { Receipt } from 'lucide-react'
import { Card, CardHeader } from '@/components/ui/Card'
import { EmptyState, ErrorState, LoadingBlock } from '@/components/ui/Feedback'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatMoney, formatRelative } from '@/lib/format'
import { PAYMENT_METHOD_LABEL, listPayments } from '@/services/finance'

/** آخر ما دخل الصندوق — مقروءاً في سطر واحد لكل عملية. */
export function PaymentsFeed() {
  const load = useCallback(
    () =>
      listPayments({
        search: '',
        status: 'paid',
        method: 'all',
        kind: 'all',
        days: 'all',
        page: 0,
        pageSize: 5,
      }),
    [],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [])

  return (
    <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
      <CardHeader
        title="أحدث العمليات المالية"
        subtitle="الدفعات الناجحة فقط"
        actions={
          <Link
            to="/payments"
            className="text-xs font-medium text-accent underline underline-offset-4"
          >
            السجل الكامل
          </Link>
        }
      />

      {loading ? (
        <LoadingBlock />
      ) : error && !data ? (
        <ErrorState message={error} onRetry={reload} />
      ) : !data || data.rows.length === 0 ? (
        <EmptyState title="لا توجد عمليات بعد" />
      ) : (
        /*
          الفواصل ذهبت والحبّات حلّت محلّها: صفٌّ يكتسب سطحه عند التحويم أقرب
          إلى ما حوله من خطٍّ رفيعٍ ثابت، ولا يجعل القائمة سلّماً من الحواف.
        */
        <ul className="flex flex-col gap-1 p-2 sm:p-2.5">
          {data.rows.map((payment) => (
            <li
              key={payment.id}
              className="glass-row flex flex-col gap-1 px-3 py-2.5 sm:px-3.5"
            >
              <div className="flex items-baseline justify-between gap-3">
                <span className="truncate text-sm font-medium text-ink">{payment.user_name}</span>
                <span className="tnum shrink-0 text-sm font-semibold whitespace-nowrap text-ink">
                  {formatMoney(payment.amount)}
                </span>
              </div>

              <div className="flex items-baseline justify-between gap-3 text-[11px]">
                <span className="truncate text-muted">{payment.provider_name || '—'}</span>
                <span className="shrink-0 text-muted">{formatRelative(payment.created_at)}</span>
              </div>

              <div className="flex items-center justify-between gap-3">
                {/* The gateway is the first thing support asks about when a
                    customer says the money left their wallet. */}
                <span className="flex items-center gap-1.5 text-[11px] text-ink-2">
                  <span
                    aria-hidden
                    className="h-1.5 w-1.5 rounded-full"
                    style={{ background: 'var(--good)' }}
                  />
                  بوابة الدفع: {PAYMENT_METHOD_LABEL[payment.method]}
                </span>
                {payment.booking_id ? (
                  <Link
                    to={`/bookings/${payment.booking_id}`}
                    dir="ltr"
                    className="glass-item tnum flex shrink-0 items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] text-muted hover:text-accent"
                  >
                    <Receipt size={11} aria-hidden />
                    {payment.reference}
                  </Link>
                ) : (
                  <span dir="ltr" className="tnum text-[11px] text-muted">
                    {payment.reference}
                  </span>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}
