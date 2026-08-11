import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Save } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { useAsync } from '@/hooks/useAsync'
import { useAuth } from '@/context/AuthContext'
import { isSupabaseConfigured } from '@/lib/supabase'
import type { AppSettings } from '@/lib/types'
import { getSettings, saveSettings } from '@/services/settings'

export function SettingsPage() {
  const { user } = useAuth()
  const load = useCallback(() => getSettings(), [])
  const { data, error, loading, reload } = useAsync(load, [])

  const [form, setForm] = useState<AppSettings | null>(null)
  const [saving, setSaving] = useState(false)
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => {
    if (data) setForm(data)
  }, [data])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  if (loading || !form) {
    if (error && !data) return <ErrorState message={error} onRetry={reload} />
    return <LoadingBlock />
  }

  const patch = (changes: Partial<AppSettings>) =>
    setForm((current) => (current ? { ...current, ...changes } : current))

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (!form) return
    setSaving(true)
    try {
      await saveSettings(form)
      setToast('تم حفظ الإعدادات.')
      reload()
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : 'تعذّر حفظ الإعدادات.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      <Card>
        <CardHeader title="حالة التطبيق" subtitle="تتحكم في وصول المستخدمين إلى التطبيق" />
        <CardBody className="flex flex-col gap-5">
          <Toggle
            checked={form.maintenance_mode}
            onChange={(next) => patch({ maintenance_mode: next })}
            label="وضع الصيانة"
            description="يعرض رسالة الصيانة ويمنع الدخول إلى التطبيق."
          />

          <Field label="رسالة الصيانة" hint="تظهر للمستخدم عند تفعيل وضع الصيانة.">
            {(id) => (
              <Textarea
                id={id}
                value={form.maintenance_message}
                onChange={(event) => patch({ maintenance_message: event.target.value })}
              />
            )}
          </Field>

          <Toggle
            checked={form.allow_signups}
            onChange={(next) => patch({ allow_signups: next })}
            label="السماح بالتسجيل"
            description="عند الإيقاف لن يتمكن مستخدمون جدد من إنشاء حسابات."
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="الحد الأدنى للإصدارات" subtitle="أقدم إصدار مسموح بتشغيله" />
        <CardBody className="flex flex-col gap-5">
          <Field label="أقل إصدار مدعوم على iOS">
            {(id) => (
              <Input
                id={id}
                dir="ltr"
                inputMode="decimal"
                placeholder="3.3.2"
                value={form.min_ios_version}
                onChange={(event) => patch({ min_ios_version: event.target.value })}
              />
            )}
          </Field>

          <Field label="أقل إصدار مدعوم على Android">
            {(id) => (
              <Input
                id={id}
                dir="ltr"
                inputMode="decimal"
                placeholder="3.2.0"
                value={form.min_android_version}
                onChange={(event) => patch({ min_android_version: event.target.value })}
              />
            )}
          </Field>

          <Field label="لغة التطبيق الافتراضية">
            {(id) => (
              <Select
                id={id}
                value={form.default_locale}
                onChange={(event) => patch({ default_locale: event.target.value })}
              >
                <option value="ar">العربية</option>
                <option value="en">English</option>
                <option value="fr">Français</option>
              </Select>
            )}
          </Field>
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="الدعم" subtitle="بيانات التواصل الظاهرة داخل التطبيق" />
        <CardBody>
          <Field label="بريد الدعم الفني">
            {(id) => (
              <Input
                id={id}
                type="email"
                dir="ltr"
                placeholder="support@example.com"
                value={form.support_email}
                onChange={(event) => patch({ support_email: event.target.value })}
              />
            )}
          </Field>
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="الحساب ومصدر البيانات" />
        <CardBody className="flex flex-col gap-3 text-xs">
          <Row label="المسؤول الحالي" value={user?.email ?? '—'} />
          <Row
            label="مصدر البيانات"
            value={isSupabaseConfigured ? 'Supabase (متصل)' : 'بيانات تجريبية محلية'}
          />
          {!isSupabaseConfigured ? (
            <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2 leading-6 text-ink-2">
              التغييرات هنا تُحفظ في الذاكرة فقط وتُفقد عند تحديث الصفحة. اربط Supabase لحفظها
              فعلياً.
            </p>
          ) : null}
        </CardBody>
      </Card>

      <div className="lg:col-span-2">
        <Button type="submit" variant="primary" disabled={saving}>
          {saving ? <Spinner /> : <Save size={15} aria-hidden />}
          حفظ الإعدادات
        </Button>
      </div>

      {toast ? <Toast message={toast} /> : null}
    </form>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-hairline pb-2 last:border-0 last:pb-0">
      <span className="text-muted">{label}</span>
      <span dir="auto" className="font-medium text-ink">
        {value}
      </span>
    </div>
  )
}
