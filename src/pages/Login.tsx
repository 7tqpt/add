import { useRef, useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { AlertCircle, BarChart3, ScrollText, ShieldCheck, Wallet } from 'lucide-react'
import { acceptInvitation, checkInvitation } from '@/services/admins'
import { ROLE_LABEL } from '@/lib/permissions'
import { Button } from '@/components/ui/Button'
import { Field, Input } from '@/components/ui/Field'
import { LoadingBlock, Spinner } from '@/components/ui/Feedback'
import { BrandLockup, BrandMark } from '@/components/brand/Brand'
import { useAuth } from '@/context/AuthContext'
import { isSupabaseConfigured } from '@/lib/supabase'

/** بطاقات لوح العلامة — أربعٌ تصف ما تفعله اللوحة فعلاً، لا شعاراتٍ عامة. */
const BRAND_POINTS = [
  { icon: BarChart3, title: 'أرقامٌ فورية', note: 'الحجوزات والإيرادات لحظةً بلحظة' },
  { icon: Wallet, title: 'مالٌ محكوم', note: 'المدفوعات والتسويات والاسترجاع' },
  { icon: ShieldCheck, title: 'صلاحياتٌ دقيقة', note: 'سبعة أدوار على تسعة محاور' },
  { icon: ScrollText, title: 'سجلٌّ لا يُمحى', note: 'كل إجراء بمن فعله ومتى' },
] as const

/**
 * ميلان اللوح خلف المؤشّر.
 *
 * الزاويتان تُكتبان في متغيّرَي CSS لا في حالة React: تحريك الحالة عند كل
 * حركة مؤشّرٍ يُعيد بناء الشجرة عشرات المرّات في الثانية، والمتغيّر يُكتب على
 * العنصر مباشرةً فيبقى التحريك في طبقة التركيب وحدها.
 *
 * والحدّ ±7 درجات: ما فوقه يقلب اللوح لوحةَ لعبٍ ويشوّه النصّ عليه.
 */
const MAX_TILT = 7

export function LoginPage() {
  const stage = useRef<HTMLElement | null>(null)

  function follow(event: { clientX: number; clientY: number }) {
    const el = stage.current
    if (!el) return
    const box = el.getBoundingClientRect()
    const x = (event.clientX - box.left) / box.width - 0.5
    const y = (event.clientY - box.top) / box.height - 0.5
    // المحور المقلوب مقصود: تحريك المؤشّر لأعلى يميل أعلى اللوح بعيداً عنه،
    // وهو ما تفعله لوحةٌ حقيقيةٌ تُمسك من حافّتها.
    el.style.setProperty('--rx', `${(-y * MAX_TILT).toFixed(2)}deg`)
    el.style.setProperty('--ry', `${(x * MAX_TILT).toFixed(2)}deg`)
  }

  function rest() {
    stage.current?.style.setProperty('--rx', '0deg')
    stage.current?.style.setProperty('--ry', '0deg')
  }

  const { user, loading, signIn, signUp, verifySignUpCode, resendSignUpCode } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [mode, setMode] = useState<'signin' | 'invite'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [token, setToken] = useState('')
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  /**
   * وُجودُه يقلب البطاقة إلى خطوة الرمز.
   *
   * ورمز الدعوة يُحفظ معه لا يُطلب ثانيةً: الموظف أدخله قبل قليل، وإعادة
   * سؤاله عنه بعد أن قطع نصف الطريق عقوبةٌ بلا سبب.
   */
  const [pending, setPending] = useState<{ email: string; token: string } | null>(null)

  /** قبول الدعوة بعد أن صارت هناك جلسة — الخطوة الأخيرة في المسارين. */
  async function claimRole(inviteToken: string) {
    const role = await acceptInvitation(inviteToken)
    setNotice(`أهلاً بك — دورك «${ROLE_LABEL[role]}».`)
    navigate('/', { replace: true })
  }

  async function handleVerify(event: FormEvent) {
    event.preventDefault()
    if (!pending) return
    setError(null)
    setNotice(null)
    setSubmitting(true)
    try {
      await verifySignUpCode(pending.email, code)
      await claimRole(pending.token)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'تعذّر تأكيد الرمز.')
    } finally {
      setSubmitting(false)
    }
  }

  async function handleResend() {
    if (!pending) return
    setError(null)
    setNotice(null)
    setSubmitting(true)
    try {
      await resendSignUpCode(pending.email)
      setNotice('أُرسل رمزٌ جديد. تحقّق من «المهملات» إن تأخّر.')
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'تعذّر إرسال الرمز.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) return <LoadingBlock label="جارٍ التحقق من الجلسة…" />

  if (user) {
    const from = (location.state as { from?: string } | null)?.from
    return <Navigate to={from && from !== '/login' ? from : '/'} replace />
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setNotice(null)
    setSubmitting(true)
    try {
      if (mode === 'signin') {
        await signIn(email.trim(), password)
        navigate('/', { replace: true })
        return
      }

      /**
       * الرمز يُفحص قبل إنشاء الحساب.
       *
       * وإلا خلّفت كل محاولةٍ خاطئة حساباً يتيماً في مصادقة Supabase لا تحذفه
       * اللوحة — حذف مستخدمي المصادقة يحتاج `service_role`، وهو لا يوضع في
       * متصفّح. والفحص قراءةٌ محضة لا تقبل الدعوة: القبول يبقى في دالته وحدها،
       * بجلسةٍ حقيقية، لأن القاعدة تقرأ البريد من رمز الجلسة لا ممّا يُرسله
       * المتصفّح.
       */
      const invited = await checkInvitation(token, email.trim())
      if (!invited) {
        throw new Error('الدعوة غير صالحة — تأكّد من الرمز ومن أنك تستعمل البريد المدعوّ.')
      }

      const needsCode = await signUp(email.trim(), password)
      if (needsCode) {
        setPending({ email: email.trim(), token })
        setNotice(`أرسلنا رمزاً إلى ${email.trim()} — اكتبه لتفعيل حسابك.`)
        return
      }
      await claimRole(token)
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : mode === 'signin'
            ? 'تعذّر تسجيل الدخول.'
            : 'تعذّر إكمال التسجيل.',
      )
    } finally {
      setSubmitting(false)
    }
  }

  return (
    /**
     * شاشةٌ منقسمة: النموذج في نصف، ولوحُ العلامة في الآخر.
     *
     * واللوح يختفي دون 1024 بكسل بدل أن ينضغط تحت النموذج: على الجوال ليس
     * وقتَ التعريف بالمنصّة، بل وقتَ الدخول إليها بأقل عدد لمسات.
     */
    <div className="grid min-h-full lg:grid-cols-2">
      {/* لوح العلامة — يُخفى عن قارئ الشاشة: زخرفةٌ لا معلومة، والنموذج يحمل
          كل ما يلزم لإتمام المهمة. */}
      <aside
        ref={stage}
        aria-hidden
        onPointerMove={follow}
        onPointerLeave={rest}
        className="scene relative hidden overflow-hidden bg-[#070c16] p-12 text-white lg:flex lg:flex-col lg:justify-center"
      >
        <div
          className="pointer-events-none absolute inset-0 opacity-90"
          style={{
            background:
              'radial-gradient(1100px 620px at 78% 12%, #1d4ed8 0%, transparent 55%),' +
              'radial-gradient(760px 520px at 12% 88%, #0e6f8c 0%, transparent 60%)',
          }}
        />

        {/* حلقةٌ ضخمةٌ طافية خلف المحتوى — عمقٌ في الخلفية لا زخرفةٌ فوقها */}
        <div
          className="float pointer-events-none absolute -end-24 top-1/2 h-[34rem] w-[34rem] -translate-y-1/2 rounded-full opacity-30"
          style={{
            border: '1px solid rgba(96,165,250,0.5)',
            boxShadow: 'inset 0 0 120px rgba(29,78,216,0.45), 0 0 90px rgba(29,78,216,0.25)',
          }}
        />

        <div className="tilt relative">
          <div className="layer-1 mb-9">
            <BrandLockup size={54} spin tone="invert" subtitle="SDD SOFTWARE" />
          </div>

          <h2 className="layer-2 max-w-lg text-4xl leading-[1.35] font-bold text-balance xl:text-5xl">
            حيث تبدأ القوة
            <span className="mt-1 block text-[#7fb2ff]">وتستمر التقنية</span>
          </h2>
          <p className="layer-2 mt-5 max-w-md text-base leading-8 text-white/70">
            الحجوزات ومقدّمو الخدمة والمدفوعات والتسويات — من مكانٍ واحد، بأرقامٍ
            فوريةٍ وسجلٍّ لكل إجراء.
          </p>

          <div className="layer-3 mt-11 grid max-w-lg grid-cols-2 gap-3.5">
            {BRAND_POINTS.map(({ icon: Icon, title, note }) => (
              <div
                key={title}
                className="rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-sm"
              >
                <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-white/10">
                  <Icon size={17} aria-hidden />
                </span>
                <p className="mt-3 text-sm font-semibold">{title}</p>
                <p className="mt-0.5 text-xs leading-6 text-white/60">{note}</p>
              </div>
            ))}
          </div>
        </div>
      </aside>

      <div className="flex items-center justify-center bg-page px-4 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-7 flex flex-col items-center gap-3 text-center lg:hidden">
            <BrandMark size={52} spin />
          </div>
          <div className="mb-7 text-center lg:text-start">
            <h1 className="text-2xl font-bold text-ink">منصة حجوزات الأعراس</h1>
            <p className="mt-1.5 text-sm text-muted">
              {pending
                ? 'خطوة أخيرة — أكّد بريدك'
                : mode === 'signin'
                  ? 'سجّل الدخول بحساب المسؤول للمتابعة'
                  : 'أنشئ حسابك برمز الدعوة الذي وصلك'}
            </p>
          </div>

        {pending ? (
          <form
            onSubmit={handleVerify}
            className="flex flex-col gap-4 rounded-xl border border-hairline bg-surface p-5"
          >
            <p className="text-xs leading-6 text-ink-2">
              أرسلنا رمزاً إلى{' '}
              <span dir="ltr" className="font-semibold text-ink">
                {pending.email}
              </span>
              . اكتبه هنا لتفعيل حسابك، ويُمنح دورك فور تأكيده.
            </p>

            <Field label="رمز التفعيل" hint="ستّة أرقام، وصلتك في رسالة بريد.">
              {(id) => (
                <Input
                  id={id}
                  required
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  dir="ltr"
                  placeholder="------"
                  className="tnum text-center text-lg tracking-[0.4em]"
                  value={code}
                  onChange={(event) => setCode(event.target.value)}
                />
              )}
            </Field>

            {error ? (
              <p
                role="alert"
                className="flex items-start gap-2 rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink"
              >
                <AlertCircle size={14} aria-hidden className="mt-0.5 shrink-0 text-[var(--critical)]" />
                {error}
              </p>
            ) : null}

            {notice ? (
              <p role="status" className="text-xs text-[var(--good)]">
                {notice}
              </p>
            ) : null}

            <Button type="submit" variant="primary" disabled={submitting}>
              {submitting ? <Spinner /> : null}
              تفعيل الحساب
            </Button>

            <button
              type="button"
              onClick={handleResend}
              disabled={submitting}
              className="cursor-pointer text-center text-xs text-ink-2 underline underline-offset-4 hover:text-ink"
            >
              لم يصلني — أعد الإرسال
            </button>

            <button
              type="button"
              // مخرجٌ ممّن أخطأ بريده: بدونه يُحبس في شاشةٍ تنتظر رمزاً لن يأتي.
              onClick={() => {
                setPending(null)
                setCode('')
                setError(null)
                setNotice(null)
              }}
              className="cursor-pointer text-center text-xs text-ink-2 underline underline-offset-4 hover:text-ink"
            >
              بياناتي خطأ — ارجع
            </button>
          </form>
        ) : (
        <form
          onSubmit={handleSubmit}
          className="flex flex-col gap-4 rounded-xl border border-hairline bg-surface p-5"
        >
          <Field label="البريد الإلكتروني">
            {(id) => (
              <Input
                id={id}
                type="email"
                required
                autoComplete="username"
                dir="ltr"
                placeholder="admin@example.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            )}
          </Field>

          <Field
            label="كلمة المرور"
            hint={mode === 'invite' ? 'اختر كلمة مرور جديدة — ٨ أحرف فأكثر.' : undefined}
          >
            {(id) => (
              <Input
                id={id}
                type="password"
                required
                minLength={mode === 'invite' ? 8 : undefined}
                autoComplete={mode === 'invite' ? 'new-password' : 'current-password'}
                dir="ltr"
                placeholder="••••••••"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
            )}
          </Field>

          {mode === 'invite' ? (
            <Field label="رمز الدعوة" hint="عشر خانات، وصلتك من مالك المنصة.">
              {(id) => (
                <Input
                  id={id}
                  required
                  dir="ltr"
                  placeholder="A1B2C3D4E5"
                  className="tnum tracking-widest"
                  value={token}
                  onChange={(event) => setToken(event.target.value.toUpperCase())}
                />
              )}
            </Field>
          ) : null}

          {error ? (
            <p
              role="alert"
              className="flex items-start gap-2 rounded-lg border border-[color-mix(in_oklab,var(--critical)_35%,transparent)] px-3 py-2 text-xs text-ink"
            >
              <AlertCircle size={14} aria-hidden className="mt-0.5 shrink-0 text-[var(--critical)]" />
              {error}
            </p>
          ) : null}

          {notice ? (
            <p role="status" className="text-xs text-[var(--good)]">
              {notice}
            </p>
          ) : null}

          <Button type="submit" variant="primary" disabled={submitting}>
            {submitting ? <Spinner /> : null}
            {mode === 'signin' ? 'تسجيل الدخول' : 'إنشاء الحساب والدخول'}
          </Button>

          <button
            type="button"
            onClick={() => {
              setMode(mode === 'signin' ? 'invite' : 'signin')
              setError(null)
              setNotice(null)
            }}
            className="cursor-pointer text-center text-xs text-ink-2 underline underline-offset-4 hover:text-ink"
          >
            {mode === 'signin' ? 'وصلني رمز دعوة — أنشئ حسابي' : 'لديّ حساب — عودة لتسجيل الدخول'}
          </button>
        </form>
        )}

        {!isSupabaseConfigured ? (
          <p className="mt-4 rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs leading-6 text-ink-2">
            <strong className="font-semibold">وضع العرض التجريبي:</strong> لم يتم ربط Supabase بعد،
            لذا يقبل النموذج أي بريد إلكتروني مع كلمة مرور من ٤ أحرف فأكثر لعرض اللوحة. للربط
            الحقيقي، شغّل{' '}
            <code dir="ltr" className="rounded bg-surface px-1">
              supabase/schema.sql
            </code>{' '}
            وأضف المفاتيح في{' '}
            <code dir="ltr" className="rounded bg-surface px-1">
              .env
            </code>
            .
          </p>
          ) : null}
        </div>
      </div>
    </div>
  )
}
