import { useEffect, useState } from 'react'
import { KeyRound, ShieldOff } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Field'
import { Spinner } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { ROLE_LABEL } from '@/lib/permissions'
import type { AdminRole } from '@/lib/types'
import { acceptInvitation, myInvitationRole } from '@/services/admins'

/** يستخرج رسالةً مفهومة من أي شكلٍ يُرمى: صنف `Error`، أو كائنٌ يحمل `message`. */
function messageOf(cause: unknown, fallback: string): string {
  if (cause instanceof Error && cause.message) return cause.message
  if (typeof cause === 'string' && cause) return cause
  if (cause && typeof cause === 'object' && 'message' in cause) {
    const { message } = cause as { message?: unknown }
    if (typeof message === 'string' && message) return message
  }
  return fallback
}

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
   * `undefined` ما دام السؤال معلّقاً، ثم الدور أو `null`.
   *
   * التمييز بين الثلاثة مقصود: عرضُ «لا دعوة لبريدك» قبل أن يصل الجواب
   * يتّهم المستخدم بما لم يُتحقّق منه بعد.
   */
  const [invited, setInvited] = useState<AdminRole | null | undefined>(undefined)

  useEffect(() => {
    let alive = true
    myInvitationRole()
      .then((role) => {
        if (alive) setInvited(role)
      })
      // عطبٌ هنا لا يحجب الشاشة: الحقل يبقى، والرسالة تعود عامّة كما كانت.
      .catch(() => {
        if (alive) setInvited(null)
      })
    return () => {
      alive = false
    }
  }, [])

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
      // لا يُكتفى بـ`instanceof Error`: كائنٌ بلا صنفٍ يحمل رسالةً نافعة كان
      // يسقط إلى نصٍّ عامّ فيضيع السبب، وهو أسوأ ما يقع لمن يقف أمام طريقٍ
      // مسدود — يقرأ «تعذّر» ولا يعرف ماذا يصلح.
      setError(messageOf(cause, 'تعذّر قبول الدعوة.'))
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

        {/*
          السبب لا الحكم. الشاشة تعرف أيّ الحالتين هي، وكتمانُه كلّف جولتين:
          بريدان يفترقان بحرفٍ واحد، فُعِّل أحدهما وظُنّ أن التفعيل لم يثبت.
        */}
        {invited === undefined ? null : invited ? (
          <p className="mt-3 text-xs leading-6 text-ink-2">
            باسم هذا البريد <span className="font-medium">دعوةٌ تنتظر</span> بدور «
            {ROLE_LABEL[invited]}». أدخل الرمز الذي أعطاك المالك ليُفعَّل حسابك في الحال.
          </p>
        ) : (
          <p className="mt-3 text-xs leading-6 text-ink-2">
            <span className="font-medium">لا توجد دعوةٌ لهذا البريد.</span> إن كنت قد فعّلت
            حسابك من قبل فالأرجح أنك دخلت بحسابٍ آخر — تحقّق من البريد أعلاه حرفاً بحرف،
            وسجّل الخروج ثم ادخل بالحساب المدعوّ.
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
