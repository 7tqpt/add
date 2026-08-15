import { useEffect, useRef, type ReactNode } from 'react'
import { AlertTriangle } from 'lucide-react'
import { Button } from './Button'
import { Spinner } from './Feedback'

/**
 * Blocking confirmation for a destructive or hard-to-undo action.
 *
 * Rendered as a native `<dialog>` so the browser supplies the modal semantics,
 * the top layer and Escape-to-close instead of a hand-rolled overlay.
 */
export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = 'تأكيد',
  cancelLabel = 'إلغاء',
  tone = 'danger',
  busy = false,
  error = null,
  confirmDisabled = false,
  onConfirm,
  onCancel,
  children,
}: {
  open: boolean
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  tone?: 'danger' | 'primary'
  busy?: boolean
  /**
   * سبب فشل التأكيد، يُعرض داخل النافذة نفسها.
   *
   * ولا يجوز عرضه في `Toast` بدلاً من هنا: النافذة تُفتح بـ`showModal()` فتُرسم
   * في الطبقة العليا للمتصفّح، وهي فوق كل `z-index` مهما ارتفع. فأيّ رسالةٍ
   * خارجها تُدفن تحت ستارها، ويرى المستخدم زرّاً «لا يفعل شيئاً» بينما
   * التطبيق يشرح له السبب في مكانٍ لا يصله بصره.
   */
  error?: string | null
  /**
   * يمنع التأكيد حتى يستوفي المستخدم شرطاً في `children` — كأن يكتب البريد
   * الذي ينقل إليه الملكية. للإجراءات التي لا رجعة فيها: النقرة وحدها تُخطئ،
   * والكتابة لا تُخطئ.
   */
  confirmDisabled?: boolean
  onConfirm: () => void
  onCancel: () => void
  /** Extra input the confirmation needs, e.g. a reason for the action. */
  children?: ReactNode
}) {
  const ref = useRef<HTMLDialogElement | null>(null)

  useEffect(() => {
    const dialog = ref.current
    if (!dialog) return
    if (open && !dialog.open) dialog.showModal()
    if (!open && dialog.open) dialog.close()
  }, [open])

  return (
    <dialog
      ref={ref}
      // Escape fires `cancel`; route it through onCancel so state stays in sync.
      onCancel={(event) => {
        event.preventDefault()
        if (!busy) onCancel()
      }}
      className="m-auto w-[min(28rem,calc(100vw-2rem))] rounded-xl border border-hairline bg-surface p-0 text-ink backdrop:bg-black/50"
    >
      <div className="flex flex-col gap-4 p-5">
        <div className="flex items-start gap-3">
          <span
            aria-hidden
            className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full"
            style={{ background: 'color-mix(in oklab, var(--critical) 12%, transparent)' }}
          >
            <AlertTriangle size={18} style={{ color: 'var(--critical)' }} />
          </span>
          <div className="min-w-0">
            <h2 className="text-sm font-semibold text-ink">{title}</h2>
            <p className="mt-1 text-xs leading-6 text-ink-2">{message}</p>
          </div>
        </div>

        {children ? <div className="flex flex-col gap-3">{children}</div> : null}

        {error ? (
          <p
            role="alert"
            className="rounded-lg border px-3 py-2.5 text-xs leading-6"
            style={{
              borderColor: 'color-mix(in oklab, var(--critical) 35%, transparent)',
              background: 'color-mix(in oklab, var(--critical) 8%, transparent)',
              color: 'var(--text-primary)',
            }}
          >
            {error}
          </p>
        ) : null}

        <div className="flex justify-start gap-2">
          <Button
            variant={tone === 'danger' ? 'danger' : 'primary'}
            size="sm"
            disabled={busy || confirmDisabled}
            onClick={onConfirm}
          >
            {busy ? <Spinner /> : null}
            {confirmLabel}
          </Button>
          <Button variant="secondary" size="sm" disabled={busy} onClick={onCancel}>
            {cancelLabel}
          </Button>
        </div>
      </div>
    </dialog>
  )
}
