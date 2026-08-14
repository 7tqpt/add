import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { AlertCircle, PartyPopper } from 'lucide-react'
import { acceptInvitation } from '@/services/admins'
import { ROLE_LABEL } from '@/lib/permissions'
import { Button } from '@/components/ui/Button'
import { Field, Input } from '@/components/ui/Field'
import { LoadingBlock, Spinner } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { isSupabaseConfigured } from '@/lib/supabase'

export function LoginPage() {
  const { user, loading, signIn, signUp } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [mode, setMode] = useState<'signin' | 'invite'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [token, setToken] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

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
       * الترتيب مقصود: يُنشأ الحساب أولاً ثم تُقبل الدعوة.
       *
       * قبول الدعوة يقرأ بريد المتصل من رمز الجلسة، فلا جلسة تعني لا بريد تعني
       * رفضاً. ولو انقطع الاتصال بين الخطوتين بقي الحساب بلا دور — والرمز ما
       * زال صالحاً، فيكفي تسجيل الدخول وإعادة إدخاله.
       */
      await signUp(email.trim(), password)
      const role = await acceptInvitation(token)
      setNotice(`أهلاً بك — دورك «${ROLE_LABEL[role]}».`)
      navigate('/', { replace: true })
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
    <div className="flex min-h-full items-center justify-center bg-page px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center gap-3 text-center">
          <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-accent text-accent-ink">
            <PartyPopper size={22} aria-hidden />
          </span>
          <div>
            <h1 className="text-lg font-semibold text-ink">منصة حجوزات الأعراس</h1>
            <p className="mt-1 text-xs text-muted">
              {mode === 'signin'
                ? 'سجّل الدخول بحساب المسؤول للمتابعة'
                : 'أنشئ حسابك برمز الدعوة الذي وصلك'}
            </p>
          </div>
        </div>

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
  )
}
