import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { AlertCircle, Smartphone } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Field, Input } from '@/components/ui/Field'
import { LoadingBlock, Spinner } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { isSupabaseConfigured } from '@/lib/supabase'

export function LoginPage() {
  const { user, loading, signIn } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  if (loading) return <LoadingBlock label="جارٍ التحقق من الجلسة…" />

  if (user) {
    const from = (location.state as { from?: string } | null)?.from
    return <Navigate to={from && from !== '/login' ? from : '/'} replace />
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      await signIn(email.trim(), password)
      navigate('/', { replace: true })
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'تعذّر تسجيل الدخول.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex min-h-full items-center justify-center bg-page px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center gap-3 text-center">
          <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-series-1 text-white">
            <Smartphone size={22} aria-hidden />
          </span>
          <div>
            <h1 className="text-lg font-semibold text-ink">لوحة تحكم التطبيق</h1>
            <p className="mt-1 text-xs text-muted">سجّل الدخول بحساب المسؤول للمتابعة</p>
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

          <Field label="كلمة المرور">
            {(id) => (
              <Input
                id={id}
                type="password"
                required
                autoComplete="current-password"
                dir="ltr"
                placeholder="••••••••"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
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

          <Button type="submit" variant="primary" disabled={submitting}>
            {submitting ? <Spinner /> : null}
            تسجيل الدخول
          </Button>
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
