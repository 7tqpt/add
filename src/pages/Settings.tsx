import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Save } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { useAsync } from '@/hooks/useAsync'
import { useAuth } from '@/context/AuthContext'
import { formatDate } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import type { AdminRole, AppSettings } from '@/lib/types'
import {
  ROLE_DESCRIPTION,
  ROLE_LABEL,
  listAdmins,
  setAdminRole,
} from '@/services/admins'
import { getSettings, saveSettings } from '@/services/settings'

export function SettingsPage() {
  const { user, role, canWrite } = useAuth()
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
            label="السماح بتسجيل العملاء"
            description="عند الإيقاف لن يتمكن عملاء جدد من إنشاء حسابات."
          />

          <Toggle
            checked={form.allow_provider_signups}
            onChange={(next) => patch({ allow_provider_signups: next })}
            label="استقبال طلبات مقدّمي الخدمة"
            description="عند الإيقاف يُخفى نموذج الانضمام؛ الطلبات المعلّقة تبقى للمراجعة."
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader
          title="العمولة والعربون"
          subtitle="القيم الافتراضية للمنصة — تسري على الحجوزات الجديدة فقط"
        />
        <CardBody className="flex flex-col gap-5">
          <Field
            label="نسبة عمولة المنصة العامة (%)"
            hint="تُطبَّق على كل شريك ليس له نسبة خاصة في صفحته."
          >
            {(id) => (
              <Input
                id={id}
                type="number"
                min={0}
                max={100}
                dir="ltr"
                className="tnum text-start"
                value={String(form.commission_percent)}
                onChange={(event) => patch({ commission_percent: Number(event.target.value) })}
              />
            )}
          </Field>

          <Field
            label="نسبة العربون الافتراضية (%)"
            hint="ما يدفعه العميل لتأكيد الحجز حين لا تحدّد الخدمة نسبتها."
          >
            {(id) => (
              <Input
                id={id}
                type="number"
                min={0}
                max={100}
                dir="ltr"
                className="tnum text-start"
                value={String(form.default_deposit_percent)}
                onChange={(event) =>
                  patch({ default_deposit_percent: Number(event.target.value) })
                }
              />
            )}
          </Field>

          <Field label="العملة" hint="تظهر في كل المبالغ داخل التطبيق واللوحة.">
            {(id) => (
              <Select
                id={id}
                value={form.currency}
                onChange={(event) => patch({ currency: event.target.value })}
              >
                <option value="YER">الريال اليمني (ر.ي)</option>
                <option value="SAR">الريال السعودي (ر.س)</option>
                <option value="USD">الدولار الأمريكي ($)</option>
              </Select>
            )}
          </Field>
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
        <CardBody className="flex flex-col gap-5">
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

          <Field label="رقم الدعم (واتساب/اتصال)">
            {(id) => (
              <Input
                id={id}
                type="tel"
                dir="ltr"
                className="text-start"
                placeholder="+967700000000"
                value={form.support_phone}
                onChange={(event) => patch({ support_phone: event.target.value })}
              />
            )}
          </Field>
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="الحساب ومصدر البيانات" />
        <CardBody className="flex flex-col gap-3 text-xs">
          <Row label="المسؤول الحالي" value={user?.email ?? '—'} />
          <Row label="دورك" value={role ? ROLE_LABEL[role] : 'بلا صلاحية'} />
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
        <AdminsCard onToast={setToast} />
      </div>

      <div className="lg:col-span-2">
        <Button
          type="submit"
          variant="primary"
          disabled={saving || !canWrite}
          title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
        >
          {saving ? <Spinner /> : <Save size={15} aria-hidden />}
          حفظ الإعدادات
        </Button>
      </div>

      {toast ? <Toast message={toast} /> : null}
    </form>
  )
}

const ROLES: AdminRole[] = ['owner', 'admin', 'viewer']

function AdminsCard({ onToast }: { onToast: (message: string) => void }) {
  const { user, role, canManageAdmins, previewRole } = useAuth()
  const load = useCallback(() => listAdmins(), [])
  const { data, error, loading, refetching, reload } = useAsync(load, [])
  const [busyId, setBusyId] = useState<string | null>(null)

  async function changeRole(target: Parameters<typeof setAdminRole>[0], next: AdminRole) {
    setBusyId(target.user_id)
    try {
      await setAdminRole(target, next)
      onToast(`تم تغيير دور ${target.email} إلى ${ROLE_LABEL[next]}.`)
      reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر تغيير الدور.')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <Card className={refetching ? 'is-refetching' : undefined}>
      <CardHeader
        title="المسؤولون والصلاحيات"
        subtitle="من يستطيع الدخول إلى اللوحة وما الذي يستطيع تغييره"
      />
      <CardBody className="flex flex-col gap-4">
        <ul className="flex flex-col gap-1.5 text-xs text-ink-2">
          {ROLES.map((key) => (
            <li key={key}>
              <span className="font-medium text-ink">{ROLE_LABEL[key]}</span> — {ROLE_DESCRIPTION[key]}
            </li>
          ))}
        </ul>

        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : (
          <div className="overflow-x-auto rounded-lg border border-hairline">
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr className="bg-surface-2">
                  {['البريد', 'الدور', 'أُضيف في'].map((heading) => (
                    <th
                      key={heading}
                      scope="col"
                      className="border-b border-hairline px-3 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {(data ?? []).map((admin) => (
                  <tr key={admin.user_id} className="border-b border-hairline last:border-0">
                    <td dir="ltr" className="px-3 py-2 text-start whitespace-nowrap text-ink">
                      {admin.email}
                      {admin.user_id === user?.id ? (
                        <span className="text-muted"> (أنت)</span>
                      ) : null}
                    </td>
                    <td className="px-3 py-2">
                      <div className="w-32">
                        <Select
                          value={admin.role}
                          aria-label={`دور ${admin.email}`}
                          disabled={busyId === admin.user_id || !canManageAdmins}
                          title={canManageAdmins ? undefined : 'إدارة المسؤولين متاحة للمالك فقط'}
                          onChange={(event) => changeRole(admin, event.target.value as AdminRole)}
                        >
                          {ROLES.map((key) => (
                            <option key={key} value={key}>
                              {ROLE_LABEL[key]}
                            </option>
                          ))}
                        </Select>
                      </div>
                    </td>
                    <td className="tnum px-3 py-2 whitespace-nowrap text-ink-2">
                      {formatDate(admin.created_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!isSupabaseConfigured ? (
          <div className="flex flex-col gap-2 rounded-lg border border-hairline bg-surface-2 px-3 py-2.5">
            <p className="text-xs leading-6 text-ink-2">
              <strong className="font-semibold">معاينة الصلاحيات:</strong> بدّل دورك هنا لترى كيف
              تتغيّر اللوحة. اختر «مطّلع» ولاحظ تعطّل كل أزرار التعديل في جميع الشاشات. متاح في
              وضع العرض التجريبي فقط.
            </p>
            <div className="flex flex-wrap gap-2">
              {ROLES.map((key) => (
                <Button
                  key={key}
                  type="button"
                  size="sm"
                  variant={role === key ? 'primary' : 'secondary'}
                  onClick={() => previewRole(key)}
                >
                  {ROLE_LABEL[key]}
                </Button>
              ))}
            </div>
          </div>
        ) : null}
      </CardBody>
    </Card>
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
