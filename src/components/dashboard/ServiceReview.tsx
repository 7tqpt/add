import { useEffect, useState } from 'react'
import { Check, Hourglass, X, XCircle } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { Field, Textarea } from '@/components/ui/Field'
import type { ServiceApproval, ServiceReview } from '@/services/directory'

/**
 * مراجعةُ الخدمات (ج) — ما يتكرّر في «مقدّمو الخدمة» وصفحة المزوّد: الشارةُ
 * والزرّان ونافذةُ الرفض. خدمةٌ في قسمٍ ليس من أقسام صاحبها تنتظر الإدارة،
 * والقاعدةُ هي الحَكَم (`supabase/provider_category_lock.sql`).
 */
export function ApprovalBadge({ approval }: { approval: Exclude<ServiceApproval, 'approved'> }) {
  return approval === 'pending' ? (
    <Badge tone="warning" icon={Hourglass}>
      بانتظار الموافقة
    </Badge>
  ) : (
    <Badge tone="critical" icon={XCircle}>
      مرفوضة
    </Badge>
  )
}

export function ReviewButtons({
  review,
  canWrite,
  busy,
  onApprove,
  onReject,
  hint,
}: {
  review: ServiceReview
  canWrite: boolean
  busy: boolean
  onApprove: (review: ServiceReview) => void
  onReject: (review: ServiceReview) => void
  /** ما تفعله «موافقة» — تضيف قسمَها لأقسام صاحبها (ب). */
  hint?: string
}) {
  const title = canWrite ? undefined : 'دورك الحالي للقراءة فقط'
  return (
    <div className="flex flex-col items-start gap-1">
      <div className="flex items-center gap-1.5" data-review-buttons={review.id}>
        <Button
          size="sm"
          variant="primary"
          disabled={busy || !canWrite}
          title={title}
          onClick={() => onApprove(review)}
        >
          <Check size={14} aria-hidden />
          موافقة
        </Button>
        {/* المرفوضةُ لا تُرفض ثانيةً: تُقبل، أو تبقى حتى يعدّلها صاحبُها. */}
        {review.approval === 'pending' ? (
          <Button
            size="sm"
            variant="secondary"
            disabled={busy || !canWrite}
            title={title}
            onClick={() => onReject(review)}
          >
            <X size={14} aria-hidden />
            رفض
          </Button>
        ) : null}
      </div>
      {hint ? (
        <span data-approve-hint className="max-w-56 text-[11px] leading-relaxed whitespace-normal text-muted">
          {hint}
        </span>
      ) : null}
    </div>
  )
}

/** الرفضُ بسببٍ يصل صاحبَها — ولا يُضغط بلا سبب. */
export function RejectServiceDialog({
  review,
  busy,
  error,
  onConfirm,
  onCancel,
}: {
  review: ServiceReview | null
  busy: boolean
  error: string | null
  onConfirm: (review: ServiceReview, note: string) => void
  onCancel: () => void
}) {
  const [note, setNote] = useState('')
  useEffect(() => setNote(''), [review?.id])

  return (
    <ConfirmDialog
      open={review !== null}
      title={review ? `رفض «${review.title}»؟` : ''}
      message="تبقى مخفيّةً عن العملاء، ويصل مقدّمَ الخدمة إشعارٌ بالسبب. ويستطيع أن يعدّلها فتعود إليك للمراجعة."
      confirmLabel="ارفض"
      tone="danger"
      busy={busy}
      error={error}
      confirmDisabled={!note.trim()}
      onConfirm={() => review && onConfirm(review, note)}
      onCancel={onCancel}
    >
      <Field label="سبب الرفض">
        {(id) => (
          <Textarea
            id={id}
            data-reject-note
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="مثال: التصويرُ خارج نشاط القاعة — سجّل مقدّمَ خدمةٍ آخر للتصوير."
          />
        )}
      </Field>
    </ConfirmDialog>
  )
}
