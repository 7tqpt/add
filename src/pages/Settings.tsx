import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Save, UserMinus, UserPlus } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { useAsync } from '@/hooks/useAsync'
import { useAuth } from '@/context/AuthContext'
import { formatDate } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import type { AdminAccount, AdminRole, AppSettings } from '@/lib/types'
import {
  AREAS_IN_ORDER,
  AREA_LABEL,
  LEVEL_LABEL,
  ROLES_IN_ORDER,
  ROLE_AREAS,
} from '@/lib/permissions'
import {
  ROLE_DESCRIPTION,
  ROLE_LABEL,
  addAdmin,
  listAdmins,
  removeAdmin,
  setAdminRole,
} from '@/services/admins'
import { getSettings, saveSettings } from '@/services/settings'

export function SettingsPage() {
  const { user, role, can } = useAuth()
  const canWrite = can('settings')
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



function AdminsCard({ onToast }: { onToast: (message: string) => void }) {
  const { user, canManageAdmins } = useAuth()
  const load = useCallback(() => listAdmins(), [])
  const { data, error, loading, refetching, reload } = useAsync(load, [])
  const [busyId, setBusyId] = useState<string | null>(null)
  const [newId, setNewId] = useState('')
  const [newEmail, setNewEmail] = useState('')
  const [newRole, setNewRole] = useState<AdminRole>('support')
  const [adding, setAdding] = useState(false)
  const [removing, setRemoving] = useState<AdminAccount | null>(null)

  async function changeRole(target: AdminAccount, next: AdminRole) {
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

  async function submitNew(event: FormEvent) {
    event.preventDefault()
    if (!newId.trim() || !newEmail.trim()) return
    setAdding(true)
    try {
      await addAdmin(newId.trim(), newEmail.trim(), newRole)
      onToast(`أُضيف ${newEmail.trim()} بدور ${ROLE_LABEL[newRole]}.`)
      setNewId('')
      setNewEmail('')
      reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّرت الإضافة.')
    } finally {
      setAdding(false)
    }
  }

  async function confirmRemove() {
    if (!removing) return
    setBusyId(removing.user_id)
    try {
      await removeAdmin(removing)
      onToast(`سُحبت صلاحية ${removing.email}.`)
      reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر سحب الصلاحية.')
    } finally {
      setBusyId(null)
      setRemoving(null)
    }
  }

  return (
    <Card className={refetching ? 'is-refetching' : undefined}>
      <CardHeader
        title="المسؤولون والصلاحيات"
        subtitle="من يدخل اللوحة، وما الذي يراه ويعدّله في كل مجال"
      />
      <CardBody className="flex flex-col gap-4">
        {/*
          المصفوفة كاملةً لا قائمة أوصاف: «مساعد المدير يعدّل المدفوعات والأقسام»
          جملةٌ تُقرأ ولا تُقارَن. الجدول يُري الفرق بين دورين بنظرة واحدة.
        */}
        <div className="overflow-x-auto rounded-lg border border-hairline">
          <table className="w-full border-collapse text-[11px]">
            <thead>
              <tr className="bg-surface-2">
                <th scope="col" className="border-b border-hairline px-3 py-2 text-start font-medium whitespace-nowrap text-ink-2">
                  المجال
                </th>
                {ROLES_IN_ORDER.map((key) => (
                  <th
                    key={key}
                    scope="col"
                    className="border-b border-hairline px-2 py-2 text-center font-medium whitespace-nowrap text-ink-2"
                  >
                    {ROLE_LABEL[key]}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {AREAS_IN_ORDER.map((area) => (
                <tr key={area} className="border-b border-hairline last:border-0">
                  <th scope="row" className="px-3 py-1.5 text-start font-normal whitespace-nowrap text-ink-2">
                    {AREA_LABEL[area]}
                  </th>
                  {ROLES_IN_ORDER.map((key) => {
                    const level = ROLE_AREAS[key][area]
                    return (
                      <td key={key} className="px-2 py-1.5 text-center" title={LEVEL_LABEL[level]}>
                        {/* رمز ونصّ بديل معاً — اللون وحده لا يكفي قارئ شاشة. */}
                        <span
                          aria-label={LEVEL_LABEL[level]}
                          className={
                            level === 'write'
                              ? 'text-accent'
                              : level === 'read'
                                ? 'text-ink-2'
                                : 'text-muted'
                          }
                        >
                          {level === 'write' ? '✏️' : level === 'read' ? '👁' : '—'}
                        </span>
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <p className="text-[11px] text-muted">
          ✏️ تعديل · 👁 قراءة · — محجوب. والحجب في المال يعني ألّا يرى المبالغ أصلاً، لا
          ألّا يعدّلها.
        </p>

        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : (
          <div className="overflow-x-auto rounded-lg border border-hairline">
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr className="bg-surface-2">
                  {['البريد', 'الدور', 'أُضيف في', ''].map((heading, i) => (
                    <th
                      key={heading || i}
                      scope="col"
                      className="border-b border-hairline px-3 py-2 text-start font-medium whitespace-nowrap text-ink-2"
                    >
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {(data ?? []).map((admin) => {
                  const isMe = admin.user_id === user?.id
                  return (
                    <tr key={admin.user_id} className="border-b border-hairline last:border-0">
                      <td dir="ltr" className="px-3 py-2 text-start whitespace-nowrap text-ink">
                        {admin.email}
                        {isMe ? <span className="text-muted"> (أنت)</span> : null}
                      </td>
                      <td className="px-3 py-2">
                        <div className="w-36">
                          <Select
                            value={admin.role}
                            aria-label={`دور ${admin.email}`}
                            disabled={busyId === admin.user_id || !canManageAdmins || isMe}
                            title={
                              isMe
                                ? 'لا تستطيع تغيير دورك بنفسك'
                                : canManageAdmins
                                  ? undefined
                                  : 'إدارة المسؤولين للمالك وحده'
                            }
                            onChange={(event) => changeRole(admin, event.target.value as AdminRole)}
                          >
                            {ROLES_IN_ORDER.map((key) => (
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
                      <td className="px-3 py-2">
                        {/*
                          المالك لا يسحب صلاحية نفسه: لوحةٌ بلا مالك لا يستطيع
                          أحد أن يعيد إليها مالكاً من داخلها.
                        */}
                        {canManageAdmins && !isMe ? (
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busyId === admin.user_id}
                            onClick={() => setRemoving(admin)}
                          >
                            <UserMinus size={13} aria-hidden />
                            سحب الصلاحية
                          </Button>
                        ) : null}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {canManageAdmins ? (
          <form
            onSubmit={submitNew}
            className="flex flex-col gap-3 rounded-lg border border-hairline bg-surface-2 px-3 py-3"
          >
            <div>
              <p className="text-xs font-medium text-ink">إضافة مسؤول</p>
              {/*
                إنشاء حساب المصادقة يحتاج مفتاح الخدمة، وهو يتجاوز RLS كلها فلا
                يوضع في صفحة يفتحها متصفّح. فالحساب يُنشأ من Supabase ويُمنح
                الدور من هنا.
              */}
              <p className="mt-0.5 text-[11px] leading-5 text-muted">
                أنشئ الحساب أولاً من Supabase ← Authentication ← Add user (مع تفعيل Auto
                Confirm)، ثم انسخ الـ User UID والصقه هنا.
              </p>
            </div>

            <div className="flex flex-wrap items-end gap-2">
              <div className="min-w-56 flex-1">
                <Field label="معرّف المستخدم (UID)">
                  {(fieldId) => (
                    <Input
                      id={fieldId}
                      dir="ltr"
                      value={newId}
                      onChange={(event) => setNewId(event.target.value)}
                      placeholder="00000000-0000-0000-0000-000000000000"
                      required
                    />
                  )}
                </Field>
              </div>
              <div className="min-w-48 flex-1">
                <Field label="البريد">
                  {(fieldId) => (
                    <Input
                      id={fieldId}
                      dir="ltr"
                      type="email"
                      value={newEmail}
                      onChange={(event) => setNewEmail(event.target.value)}
                      placeholder="staff@example.com"
                      required
                    />
                  )}
                </Field>
              </div>
              <div className="w-40">
                <Field label="الدور">
                  {(fieldId) => (
                    <Select
                      id={fieldId}
                      value={newRole}
                      onChange={(event) => setNewRole(event.target.value as AdminRole)}
                    >
                      {ROLES_IN_ORDER.map((key) => (
                        <option key={key} value={key}>
                          {ROLE_LABEL[key]}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
              </div>
              <Button type="submit" variant="primary" disabled={adding}>
                <UserPlus size={14} aria-hidden />
                إضافة
              </Button>
            </div>

            <p className="text-[11px] text-ink-2">{ROLE_DESCRIPTION[newRole]}</p>
          </form>
        ) : null}

      </CardBody>

      <ConfirmDialog
        open={removing !== null}
        title="سحب صلاحية الدخول"
        message={`لن يستطيع ${removing?.email ?? ''} فتح لوحة التحكم بعد الآن. حساب المصادقة يبقى كما هو — قد يكون له حساب عميل على التطبيق.`}
        confirmLabel="سحب الصلاحية"
        tone="danger"
        onConfirm={confirmRemove}
        onCancel={() => setRemoving(null)}
      />
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
