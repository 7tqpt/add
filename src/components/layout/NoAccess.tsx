import { useState } from 'react'
import { KeyRound, ShieldOff } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Field'
import { Spinner } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { acceptInvitation } from '@/services/admins'

/**
 * حساب صحيح بلا صلاحية إدارة.
 *
 * تظهر لحالتين: مسؤول أُنشئ حسابه ولم يُسجَّل في جدول `admins` بعد، وعميل أو
 * مقدّم خدمة حاول الدخول بحساب تطبيقه. الرسالة واحدة عمداً — لا تكشف للثاني
 * ما ينقصه ليصير الأول.
 */
export function NoAccess() {
  const { user, signOut, refreshRole } = useAuth()
  const [busy, setBusy] = useState(false)
  const [redeeming, setRedeeming] = useState(false)
  const [token, setToken] = useState('')
  const [error, setError] = useState<string | null>(null)

  /**
   * قبول الدعوة من هنا لا من صفحة الدخول.
   *
   * فالتسجيل والقبول خطوتان، ومن سجّل حسابه بالطريق العادي ثم وصل إلى هذه
   * الشاشة كان يجدها طريقاً مسدوداً: معه رمزٌ صحيح ولا موضع يُدخله فيه، وزرُّ
   * الخروج وحده أمامه. وهذا الموضع هو الصحيح للرمز أصلاً، لأن
   * `api_accept_invitation` تشترط جلسةً قائمة — وهي قائمةٌ الآن.
   *
   * وإظهار الحقل لا يكشف شيئاً لمن ليس مدعوّاً: السرُّ هو الرمز نفسه،
   * والقاعدة تشترط معه أن يكون البريد المسجَّل هو البريد المدعوّ.
   */
  async function redeem() {
    const clean = token.trim()
    if (!clean) return
    setRedeeming(true)
    setError(null)
    try {
      await acceptInvitation(clean)
      // لا تُعاد الصفحة تحميلاً: `refreshRole` تُعيد قراءة الدور فيُستبدل
      // هذا المكوّن باللوحة في المكان.
      refreshRole()
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'تعذّر قبول الدعوة.')
    } finally {
      setRedeeming(false)
    }
  }

  return (
    <div className="flex min-h-full items-center justify-center bg-page p-6">
      <Card className="w-full max-w-md p-6 text-center sm:p-8">
        <span
          aria-hidden
          className="mx-auto flex h-12 w-12 items-center justify-center rounded-full"
          style={{ background: 'color-mix(in oklab, var(--critical) 12%, transparent)' }}
        >
          <ShieldOff size={22} style={{ color: 'var(--critical)' }} />
        </span>

        <h1 className="mt-4 text-base font-semibold text-ink">لا تملك صلاحية الدخول</h1>

        <p className="mt-2 text-sm leading-7 text-ink-2">
          الحساب <span dir="ltr" className="font-medium">{user?.email}</span> موثَّق، لكنه ليس
          حساب إدارة. لوحة التحكم مخصّصة لفريق المنصة وحده.
        </p>

        {redeeming || token || error ? null : (
          <p className="mt-3 text-xs leading-6 text-muted">
            إن دعاك المالك وأعطاك رمزاً، فأدخله أدناه ليُفعَّل حسابك في الحال.
          </p>
        )}

        <div className="mt-5 flex flex-col gap-2 text-start">
          <label htmlFor="invite-token" className="text-xs font-medium text-ink-2">
            رمز الدعوة
          </label>
          <Input
            id="invite-token"
            value={token}
            onChange={(event) => {
              setToken(event.target.value)
              setError(null)
            }}
            // الرمز لاتيني بحروف كبيرة، فالإدخال يُعرض كذلك مهما كُتب.
            dir="ltr"
            autoCapitalize="characters"
            spellCheck={false}
            placeholder="A1B2C3D4E5"
            className="text-center tracking-[0.3em] uppercase"
            onKeyDown={(event) => {
              if (event.key === 'Enter') void redeem()
            }}
          />
          {error ? (
            <p role="alert" className="text-xs leading-6 text-[var(--critical)]">
              {error}
            </p>
          ) : null}
        </div>

        {/* الأساسيّ هنا هو التفعيل لا الخروج: من وصل إلى هذه الشاشة ومعه رمز
            جاء ليدخل، والخروج مهربٌ لا هدف. وزرّان بوزنٍ واحد لا يقولان ذلك. */}
        <Button
          variant="primary"
          className="mt-3 w-full"
          disabled={redeeming || !token.trim()}
          onClick={() => void redeem()}
        >
          {redeeming ? <Spinner /> : <KeyRound size={15} aria-hidden />}
          تفعيل حسابي
        </Button>

        <Button
          variant="secondary"
          className="mt-2 w-full"
          disabled={busy}
          onClick={async () => {
            setBusy(true)
            try {
              await signOut()
            } finally {
              setBusy(false)
            }
          }}
        >
          {busy ? <Spinner /> : null}
          تسجيل الخروج
        </Button>
      </Card>
    </div>
  )
}
