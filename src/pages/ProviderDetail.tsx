import { useCallback, useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  ArrowRight,
  BadgeCheck,
  Ban,
  Check,
  ExternalLink,
  FileText,
  Package,
  RotateCcw,
  Wallet,
  X,
  XCircle,
} from 'lucide-react'
import { StatTile } from '@/components/charts/StatTile'
import { Badge, type Tone } from '@/components/ui/Badge'
import { Button, buttonClass } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input } from '@/components/ui/Field'
import { Rating } from '@/components/ui/Rating'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { isDesktop, openExternal } from '@/lib/desktop'
import {
  formatDate,
  formatDuration,
  formatMoney,
  formatMoneyCompact,
  formatNumber,
} from '@/lib/format'
import type {
  DocumentStatus,
  ProviderDocument,
  ProviderStatus,
  ServiceMedia,
  ServiceProvider,
} from '@/lib/types'
import {
  DOCUMENT_STATUS_LABEL,
  DOCUMENT_TYPE_LABEL,
  PROVIDER_STATUS_LABEL,
  deleteServiceMedia,
  getProvider,
  getProviderPortfolio,
  serviceMediaUrl,
  setDocumentStatus,
  setProviderCommission,
  setProviderStatus,
} from '@/services/directory'
import { REVIEW_STATUS_LABEL, listProviderReviews } from '@/services/trust'

const STATUS_TONE: Record<ProviderStatus, Tone> = {
  verified: 'good',
  pending: 'warning',
  suspended: 'critical',
  rejected: 'neutral',
}

const DOCUMENT_TONE: Record<DocumentStatus, Tone> = {
  approved: 'good',
  pending: 'warning',
  rejected: 'critical',
}

interface PendingAction {
  status: ProviderStatus
  title: string
  message: string
  confirmLabel: string
  tone: 'danger' | 'primary'
}

export function ProviderDetailPage() {
  const { id = '' } = useParams()
  const { can } = useAuth()
  const canWrite = can('directory')
  const [toast, setToast] = useState<string | null>(null)
  const [pending, setPending] = useState<PendingAction | null>(null)
  const [pendingMedia, setPendingMedia] = useState<ServiceMedia | null>(null)
  const [busy, setBusy] = useState(false)

  const loadProvider = useCallback(() => getProvider(id), [id])
  const loadPortfolio = useCallback(() => getProviderPortfolio(id), [id])

  const loadReviews = useCallback(() => listProviderReviews(id), [id])

  const provider = useAsync(loadProvider, [id])
  const portfolio = useAsync(loadPortfolio, [id])
  const reviews = useAsync(loadReviews, [id])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  async function applyStatus(record: ServiceProvider, status: ProviderStatus) {
    setBusy(true)
    try {
      await setProviderStatus(record, status)
      setToast(`تم تحديث الحالة إلى «${PROVIDER_STATUS_LABEL[status]}».`)
      provider.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث الحالة.')
    } finally {
      setBusy(false)
      setPending(null)
    }
  }

  async function removeMedia(item: ServiceMedia) {
    setBusy(true)
    try {
      await deleteServiceMedia(item)
      setToast('حُذف الوسيط من الخدمة ومن التخزين.')
      portfolio.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر حذف الوسيط.')
    } finally {
      setBusy(false)
      setPendingMedia(null)
    }
  }

  async function reviewDocument(
    record: ServiceProvider,
    document: ProviderDocument,
    status: DocumentStatus,
  ) {
    setBusy(true)
    try {
      await setDocumentStatus(
        record,
        document,
        status,
        status === 'rejected' ? 'المستند غير مقبول — يرجى إعادة الرفع.' : '',
      )
      setToast(status === 'approved' ? 'تم قبول المستند.' : 'تم رفض المستند.')
      portfolio.reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر تحديث المستند.')
    } finally {
      setBusy(false)
    }
  }

  if (provider.loading) return <LoadingBlock />
  if (provider.error && !provider.data) {
    return <ErrorState message={provider.error} onRetry={provider.reload} />
  }
  if (!provider.data) {
    return (
      <Card>
        <EmptyState
          title="مقدّم الخدمة غير موجود"
          description="ربما حُذف الحساب أو أن الرابط غير صحيح."
          action={
            <Link
              to="/providers"
              className="text-sm font-medium text-accent underline underline-offset-4"
            >
              العودة إلى القائمة
            </Link>
          }
        />
      </Card>
    )
  }

  const record = provider.data
  const documents = portfolio.data?.documents ?? []
  const services = portfolio.data?.services ?? []
  const documentUrls = portfolio.data?.documentUrls ?? {}
  const media = portfolio.data?.media ?? {}
  const reviewRows = reviews.data ?? []
  const allApproved = documents.length > 0 && documents.every((doc) => doc.status === 'approved')

  return (
    <div className="flex flex-col gap-4">
      <Link
        to="/providers"
        className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-ink-2 hover:text-ink"
      >
        {/* Under RTL "back" points toward the start edge, which is the right. */}
        <ArrowRight size={14} aria-hidden />
        كل مقدّمي الخدمة
      </Link>

      <Card>
        <CardHeader
          title={record.full_name}
          subtitle={`${record.business_name} · ${record.categories.join('، ')} · ${record.governorate}`}
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Badge
                tone={STATUS_TONE[record.status]}
                icon={record.status === 'rejected' ? XCircle : true}
              >
                {PROVIDER_STATUS_LABEL[record.status]}
              </Badge>

              {record.status === 'pending' ? (
                <>
                  <Button
                    size="sm"
                    variant="primary"
                    disabled={busy || !canWrite || !allApproved}
                    title={
                      !canWrite
                        ? 'دورك الحالي للقراءة فقط'
                        : allApproved
                          ? undefined
                          : 'راجع كل المستندات واقبلها قبل التوثيق'
                    }
                    onClick={() =>
                      setPending({
                        status: 'verified',
                        title: 'توثيق مقدّم الخدمة؟',
                        message: `سيصبح ${record.business_name || record.full_name} قادراً على استقبال الحجوزات فوراً. سيُسجَّل هذا الإجراء باسمك في سجل العمليات.`,
                        confirmLabel: 'توثيق وتفعيل',
                        tone: 'primary',
                      })
                    }
                  >
                    <BadgeCheck size={14} aria-hidden />
                    توثيق
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={busy || !canWrite}
                    title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                    onClick={() =>
                      setPending({
                        status: 'rejected',
                        title: 'رفض الطلب؟',
                        message: `سيُرفض طلب ${record.business_name || record.full_name} ولن يتمكن من استقبال الحجوزات. يمكنك إعادته للمراجعة لاحقاً.`,
                        confirmLabel: 'رفض الطلب',
                        tone: 'danger',
                      })
                    }
                  >
                    <X size={14} aria-hidden />
                    رفض
                  </Button>
                </>
              ) : null}

              {record.status === 'verified' ? (
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={busy || !canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() =>
                    setPending({
                      status: 'suspended',
                      title: 'إيقاف مقدّم الخدمة؟',
                      message: `سيتوقف ${record.business_name || record.full_name} عن استقبال أي حجوزات جديدة فوراً. الحجوزات المؤكدة لا تتأثر.`,
                      confirmLabel: 'إيقاف',
                      tone: 'danger',
                    })
                  }
                >
                  <Ban size={14} aria-hidden />
                  إيقاف
                </Button>
              ) : null}

              {record.status === 'suspended' || record.status === 'rejected' ? (
                <Button
                  size="sm"
                  disabled={busy || !canWrite}
                  title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                  onClick={() =>
                    applyStatus(record, record.status === 'suspended' ? 'verified' : 'pending')
                  }
                >
                  <RotateCcw size={14} aria-hidden />
                  {record.status === 'suspended' ? 'إعادة التفعيل' : 'إعادة للمراجعة'}
                </Button>
              ) : null}
            </div>
          }
        />
        <CardBody>
          <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-xs sm:grid-cols-3 lg:grid-cols-5">
            <Detail label="البريد" value={record.email} ltr />
            <Detail label="الجوال" value={record.phone} ltr />
            <Detail label="التقييم" node={<Rating value={record.rating} count={record.reviews_count} />} />
            <Detail label="تاريخ التقديم" value={formatDate(record.applied_at)} />
            <Detail
              label="تاريخ التوثيق"
              value={record.verified_at ? formatDate(record.verified_at) : '—'}
            />
            <Detail label="المحافظة" value={record.governorate} />
            <Detail
              label="مناطق التغطية"
              value={record.coverage_areas.join('، ') || 'المحافظة فقط'}
            />
          </dl>

          {record.bio ? (
            <p className="mt-3 text-xs leading-6 text-ink-2">{record.bio}</p>
          ) : null}
          {record.status === 'rejected' && record.rejection_reason ? (
            <p className="mt-3 rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink">
              سبب الرفض: {record.rejection_reason}
            </p>
          ) : null}
        </CardBody>
      </Card>

      <div className="stagger grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile
          label="الحجوزات المنفّذة"
          tone="azure"
          value={formatNumber(record.completed_bookings)}
          icon={Package}
          refetching={provider.refetching}
        />
        <StatTile
          label="إجمالي الأرباح"
          tone="emerald"
          value={formatMoneyCompact(record.total_earnings)}
          valueTitle={formatMoney(record.total_earnings)}
          icon={Wallet}
          refetching={provider.refetching}
        />
        <CommissionCard record={record} onDone={setToast} onSaved={provider.reload} />
      </div>

      {portfolio.loading ? (
        <Card>
          <LoadingBlock />
        </Card>
      ) : portfolio.error && !portfolio.data ? (
        <Card>
          <ErrorState message={portfolio.error} onRetry={portfolio.reload} />
        </Card>
      ) : (
        <>
          <Card className={cn(portfolio.refetching && 'is-refetching')}>
            <CardHeader
              title="مستندات التوثيق"
              subtitle={
                allApproved
                  ? 'كل المستندات مقبولة'
                  : `${formatNumber(documents.filter((doc) => doc.status !== 'approved').length)} مستند بحاجة إلى مراجعة`
              }
            />
            {documents.length === 0 ? (
              <EmptyState title="لم تُرفع أي مستندات" />
            ) : (
              <ul className="divide-y divide-[var(--border)]">
                {documents.map((document) => {
                  const url = documentUrls[document.id]
                  return (
                  <li
                    key={document.id}
                    className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-5"
                  >
                    <div className="flex min-w-0 items-center gap-3">
                      <FileText size={16} aria-hidden className="shrink-0 text-muted" />
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-ink">
                          {DOCUMENT_TYPE_LABEL[document.type] ?? document.type}
                        </p>
                        <p dir="ltr" className="truncate text-start text-[11px] text-muted">
                          {document.file_name}
                        </p>
                        {url ? null : (
                          <p className="mt-0.5 text-[11px] text-muted">
                            لا يوجد ملف مرفوع — لا يمكن قبوله
                          </p>
                        )}
                        {document.note ? (
                          <p className="mt-0.5 text-[11px] text-[var(--critical)]">{document.note}</p>
                        ) : null}
                      </div>
                    </div>

                    <div className="flex shrink-0 items-center gap-2">
                      <Badge tone={DOCUMENT_TONE[document.status]}>
                        {DOCUMENT_STATUS_LABEL[document.status]}
                      </Badge>
                      {url ? (
                        <a
                          className={buttonClass('secondary', 'sm')}
                          href={url}
                          target="_blank"
                          rel="noopener noreferrer"
                          // في برنامج سطح المكتب لا يفتح `_blank` شيئاً:
                          // Tauri يمنع الانتقال إلى عنوانٍ خارجي داخل
                          // النافذة. فيُسلَّم الرابط إلى متصفّح النظام —
                          // وهو الموضع الصحيح له أصلاً، إذ نافذةٌ بلا شريط
                          // عنوانٍ ولا زرِّ رجوعٍ مصيدةٌ لا متصفّح.
                          onClick={(event) => {
                            if (!isDesktop) return
                            event.preventDefault()
                            void openExternal(url)
                          }}
                        >
                          <ExternalLink size={14} aria-hidden />
                          عرض
                        </a>
                      ) : null}
                      {/*
                        القبول يتطلّب ملفاً يُقرأ. الموافقة على مستند لا تراه ليست
                        مراجعة — وهي تمنح مقدّم الخدمة توثيقاً لم يُتحقّق منه أحد.
                        الرفض يبقى متاحاً: «لم يرفع شيئاً» سبب وجيه للرفض.
                      */}
                      {document.status !== 'approved' ? (
                        <Button
                          size="sm"
                          disabled={busy || !canWrite || !url}
                          title={
                            !canWrite
                              ? 'دورك الحالي للقراءة فقط'
                              : url
                                ? undefined
                                : 'لا يوجد ملف مرفوع لمراجعته'
                          }
                          onClick={() => reviewDocument(record, document, 'approved')}
                        >
                          <Check size={14} aria-hidden />
                          قبول
                        </Button>
                      ) : null}
                      {document.status !== 'rejected' ? (
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={busy || !canWrite}
                          title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                          onClick={() => reviewDocument(record, document, 'rejected')}
                        >
                          <X size={14} aria-hidden />
                          رفض
                        </Button>
                      ) : null}
                    </div>
                  </li>
                  )
                })}
              </ul>
            )}
          </Card>

          <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
            <Card className="overflow-hidden">
              <CardHeader title="الخدمات المعروضة" subtitle={`${formatNumber(services.length)} خدمة`} />
              {services.length === 0 ? (
                <EmptyState title="لا توجد خدمات معروضة" />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full border-collapse text-xs">
                    <thead>
                      <tr className="glass-item">
                        {['الخدمة', 'السعر', 'المدة', 'الحالة'].map((heading) => (
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
                      {services.map((service) => (
                        <tr key={service.id} className="glass-row border-b border-hairline last:border-0">
                          <td className="px-4 py-2.5 text-ink">
                            {service.title}
                            {/* الوسائط تحت اسم الخدمة لا في عمودٍ خاص: عمودٌ
                                خامس يضيّق الجدول على شاشةٍ ضيّقة، والوسائط
                                تُراجَع بالنظر لا بالمسح السريع. */}
                            <ServiceMediaStrip
                              media={media[service.id] ?? []}
                              canWrite={canWrite}
                              onDelete={setPendingMedia}
                            />
                          </td>
                          <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                            {formatMoney(service.price)}
                          </td>
                          <td className="tnum px-4 py-2.5 whitespace-nowrap text-ink-2">
                            {formatDuration(service.duration_minutes * 60)}
                          </td>
                          <td className="px-4 py-2.5">
                            <Badge tone={service.is_active ? 'good' : 'neutral'}>
                              {service.is_active ? 'معروضة' : 'مخفية'}
                            </Badge>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>

            <Card className={cn(reviews.refetching && 'is-refetching')}>
              <CardHeader
                title="أحدث التقييمات"
                subtitle={`${formatNumber(record.reviews_count)} تقييم عبر تاريخ الشريك`}
                actions={
                  <Link
                    to="/reviews"
                    className="text-xs font-medium text-accent underline underline-offset-4"
                  >
                    كل التقييمات
                  </Link>
                }
              />
              {reviews.loading ? (
                <LoadingBlock />
              ) : reviews.error && !reviews.data ? (
                <ErrorState message={reviews.error} onRetry={reviews.reload} />
              ) : reviewRows.length === 0 ? (
                <EmptyState
                  title="لا توجد تقييمات حديثة"
                  description="متوسط التقييم في الأعلى محسوب من كامل سجل الشريك."
                />
              ) : (
                <ul className="max-h-96 divide-y divide-[var(--border)] overflow-auto">
                  {reviewRows.map((review) => (
                    <li key={review.id} className="flex flex-col gap-1.5 px-4 py-3 sm:px-5">
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <p className="text-sm font-medium text-ink">{review.user_name}</p>
                        <div className="flex items-center gap-2">
                          {/* A hidden review still counts for the admin reading
                              this page, but it must be visibly marked as hidden. */}
                          {review.status !== 'published' ? (
                            <Badge tone={review.status === 'flagged' ? 'serious' : 'neutral'}>
                              {REVIEW_STATUS_LABEL[review.status]}
                            </Badge>
                          ) : null}
                          <Rating value={review.rating} />
                        </div>
                      </div>
                      <p className="text-xs leading-6 text-ink-2">{review.comment}</p>
                      <p className="tnum text-[11px] text-muted">{formatDate(review.created_at)}</p>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>
        </>
      )}

      <ConfirmDialog
        open={pendingMedia !== null}
        title="حذف وسيط الخدمة؟"
        message="يُحذف من الخدمة ومن التخزين ولا يُسترجع. استعمله لما يُخالف شروط النشر."
        confirmLabel="احذف"
        tone="danger"
        busy={busy}
        onConfirm={() => pendingMedia && removeMedia(pendingMedia)}
        onCancel={() => setPendingMedia(null)}
      />

      <ConfirmDialog
        open={pending !== null}
        title={pending?.title ?? ''}
        message={pending?.message ?? ''}
        confirmLabel={pending?.confirmLabel}
        tone={pending?.tone}
        busy={busy}
        onConfirm={() => pending && applyStatus(record, pending.status)}
        onCancel={() => setPending(null)}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

function CommissionCard({
  record,
  onDone,
  onSaved,
}: {
  record: ServiceProvider
  onDone: (message: string) => void
  onSaved: () => void
}) {
  const { canWrite } = useAuth()
  // An empty field is not "0%" — it means this partner has no override and the
  // platform-wide rate applies, which is stored as null.
  const asText = (percent: number | null) => (percent === null ? '' : String(percent))
  const [value, setValue] = useState(asText(record.commission_percent))
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    setValue(asText(record.commission_percent))
  }, [record.commission_percent])

  const trimmed = value.trim()
  const parsed = trimmed === '' ? null : Number(trimmed)
  const valid = parsed === null || (Number.isFinite(parsed) && parsed >= 0 && parsed <= 100)
  const changed = valid && parsed !== record.commission_percent

  async function save() {
    if (!changed) return
    setBusy(true)
    try {
      await setProviderCommission(record, parsed)
      onDone('تم تحديث نسبة العمولة.')
      onSaved()
    } catch (cause) {
      onDone(cause instanceof Error ? cause.message : 'تعذّر حفظ العمولة.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Card className="p-4 sm:p-5">
      <p className="text-xs font-medium text-ink-2">عمولة خاصة بهذا الشريك</p>
      <div className="mt-2 flex items-center gap-2">
        <div className="w-24">
          <Input
            type="number"
            min={0}
            max={100}
            value={value}
            disabled={busy || !canWrite}
            aria-label="نسبة العمولة بالمئة"
            placeholder="العامة"
            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
            onChange={(event) => setValue(event.target.value)}
          />
        </div>
        <span className="text-sm text-ink-2">%</span>
        <Button size="sm" variant="primary" disabled={!changed || busy || !canWrite} onClick={save}>
          حفظ
        </Button>
      </div>
      {!valid ? (
        <p className="mt-2 text-xs text-[var(--critical)]">أدخل رقماً بين 0 و 100، أو اترك الحقل فارغاً.</p>
      ) : (
        <p className="mt-2 text-xs text-muted">
          {parsed === null
            ? 'فارغ = تُطبَّق نسبة المنصة العامة من الإعدادات.'
            : 'تُخصم من كل حجز يُنفّذه هذا الشريك بدل النسبة العامة.'}
        </p>
      )}
    </Card>
  )
}

function Detail({
  label,
  value,
  node,
  ltr,
}: {
  label: string
  value?: string
  node?: ReactNode
  ltr?: boolean
}) {
  return (
    <div className="min-w-0">
      <dt className="text-muted">{label}</dt>
      <dd
        dir={ltr ? 'ltr' : undefined}
        className={`mt-0.5 truncate font-medium text-ink ${ltr ? 'text-start' : ''}`}
      >
        {node ?? value}
      </dd>
    </div>
  )
}


/**
 * شريط وسائط الخدمة في اللوحة.
 *
 * المراجعة هنا بالنظر: صورةٌ تُرى، ومقطعٌ يُفتح في تبويبٍ جديد. ولا مشغّل
 * داخل اللوحة — المسؤول يفتح المقطع مرّةً ليحكم عليه، لا ليشاهده في مكانه،
 * ومشغّلٌ مضمَّن في صفٍّ من جدولٍ يزاحم ما حوله.
 */
function ServiceMediaStrip({
  media,
  canWrite,
  onDelete,
}: {
  media: ServiceMedia[]
  canWrite: boolean
  onDelete: (item: ServiceMedia) => void
}) {
  // خدمةٌ بلا وسائط لا تعرض شيئاً: صفٌّ فارغٌ تحت كل عنوانٍ يضاعف طول الجدول
  // بلا خبر.
  if (media.length === 0) return null

  return (
    <ul className="mt-2 flex flex-wrap items-center gap-1.5">
      {media.map((item) => {
        const url = serviceMediaUrl(item.path)
        return (
          // `group` على العنصر لا على البطاقة: زرُّ الحذف أخٌ للبطاقة لا
          // ابنٌ لها، فلو كانت هي المجموعة لما أظهره المرورُ عليها أبداً.
          <li key={item.id} className="group relative">
            {item.kind === 'image' ? (
              <MediaTile url={url} label="صورة">
                {url ? (
                  <img src={url} alt="" className="h-10 w-10 rounded-md object-cover" />
                ) : (
                  <Package className="size-4 text-muted" aria-hidden />
                )}
              </MediaTile>
            ) : (
              <MediaTile url={url} label={item.kind === 'video' ? 'فيديو' : 'مقطع صوتي'}>
                <span className="tnum text-[10px] text-ink-2">
                  {item.kind === 'video' ? '▶' : '♪'} {item.duration_seconds}ث
                </span>
              </MediaTile>
            )}
            {canWrite ? (
              <button
                type="button"
                onClick={() => onDelete(item)}
                title="احذف الوسيط"
                aria-label="احذف الوسيط"
                className="absolute -top-1 -left-1 rounded-full bg-critical p-0.5 text-white opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100 hover:opacity-100"
              >
                <X className="size-2.5" aria-hidden />
              </button>
            ) : null}
          </li>
        )
      })}
    </ul>
  )
}

function MediaTile({
  url,
  label,
  children,
}: {
  url: string | null
  label: string
  children: ReactNode
}) {
  const box =
    'flex h-10 min-w-10 items-center justify-center overflow-hidden rounded-md border border-hairline bg-surface-2 px-1'
  // بلا رابطٍ لا رابط: عنصرٌ `<a>` بلا `href` ليس زرّاً ولا وصلة، ولوحةُ
  // المفاتيح تقف عنده.
  if (!url) {
    return (
      <span className={box} title={label}>
        {children}
      </span>
    )
  }
  return (
    <a
      href={url}
      target="_blank"
      rel="noreferrer"
      className={cn(box, 'hover:border-accent')}
      title={`${label} — يُفتح في تبويب جديد`}
    >
      {children}
    </a>
  )
}
