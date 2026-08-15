import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Crown, Save, Trash2, UserMinus, UserPlus } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Badge } from '@/components/ui/Badge'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { ErrorState, LoadingBlock, Spinner, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select, Textarea, Toggle } from '@/components/ui/Field'
import { useAsync } from '@/hooks/useAsync'
import { useAuth } from '@/context/AuthContext'
import { formatDate, formatRelative } from '@/lib/format'
import { isSupabaseConfigured } from '@/lib/supabase'
import type { AdminAccount, AdminInvitation, AdminRole, AppSettings } from '@/lib/types'
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
  cancelInvitation,
  inviteAdmin,
  listAdmins,
  listInvitations,
  deleteAdminAccount,
  removeAdmin,
  setAdminRole,
  transferOwnership,
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
    <div className="flex flex-col gap-4">
      {/*
        بطاقة المسؤولين خارج نموذج الإعدادات لا داخله.
        نموذجٌ داخل نموذج غير صالح في HTML، فيسقطه المتصفّح ولا يعمل onSubmit
        الداخلي أبداً — يُرسَل الخارجي مكانه. وقع ذلك فعلاً: زرّ «إضافة مسؤول»
        كان يبدو سليماً ولا يفعل شيئاً.
      */}
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
      </form>

      <AdminsCard onToast={setToast} />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}



function AdminsCard({ onToast }: { onToast: (message: string) => void }) {
  const { user, canManageAdmins, refreshRole } = useAuth()
  const load = useCallback(() => listAdmins(), [])
  const { data, error, loading, refetching, reload } = useAsync(load, [])
  const loadInvitations = useCallback(() => listInvitations(), [])
  const invitations = useAsync(loadInvitations, [])
  const [busyId, setBusyId] = useState<string | null>(null)
  const [newEmail, setNewEmail] = useState('')
  const [newRole, setNewRole] = useState<AdminRole>('support')
  const [adding, setAdding] = useState(false)
  const [removing, setRemoving] = useState<AdminAccount | null>(null)
  const [handover, setHandover] = useState<AdminAccount | null>(null)
  const [typedEmail, setTypedEmail] = useState('')
  const [handoverError, setHandoverError] = useState<string | null>(null)
  const [handingOver, setHandingOver] = useState(false)
  const [erasing, setErasing] = useState<AdminAccount | null>(null)
  const [typedErase, setTypedErase] = useState('')
  const [eraseError, setEraseError] = useState<string | null>(null)
  const [erasingBusy, setErasingBusy] = useState(false)

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
    if (!newEmail.trim()) return
    setAdding(true)
    try {
      const invitation = await inviteAdmin(newEmail.trim(), newRole)
      onToast(`رمز الدعوة ${invitation.token} — أرسله إلى ${invitation.email}.`)
      setNewEmail('')
      invitations.reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر إنشاء الدعوة.')
    } finally {
      setAdding(false)
    }
  }

  async function copyToken(token: string) {
    try {
      await navigator.clipboard.writeText(token)
      onToast('نُسخ الرمز.')
    } catch {
      // الحافظة محجوبة خارج السياقات الآمنة؛ الرمز ظاهر فيُنسخ باليد.
      onToast(`الرمز: ${token}`)
    }
  }

  async function dropInvitation(invitation: AdminInvitation) {
    try {
      await cancelInvitation(invitation)
      onToast('أُلغيت الدعوة.')
      invitations.reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر إلغاء الدعوة.')
    }
  }

  function openHandover(target: AdminAccount) {
    setTypedEmail('')
    setHandoverError(null)
    setHandover(target)
  }

  async function confirmHandover() {
    if (!handover) return
    setHandingOver(true)
    setHandoverError(null)
    try {
      const mail = await transferOwnership(handover)
      setHandover(null)
      onToast(`صار ${mail} مالك اللوحة، وأنت الآن مدير.`)
      reload()
      // دورك تغيّر من تحتك: تُعاد قراءته فتُقفل أزرار المالك من فورها بدل أن
      // تبقى معروضةً حتى تُحدّث الصفحة، فتفشل بين يديك.
      refreshRole()
    } catch (cause) {
      setHandoverError(cause instanceof Error ? cause.message : 'تعذّر نقل الملكية.')
    } finally {
      setHandingOver(false)
    }
  }

  function openErase(target: AdminAccount) {
    setTypedErase('')
    setEraseError(null)
    setErasing(target)
  }

  async function confirmErase() {
    if (!erasing) return
    setErasingBusy(true)
    setEraseError(null)
    try {
      const mail = await deleteAdminAccount(erasing)
      setErasing(null)
      onToast(`مُحي حساب ${mail} من القاعدة.`)
      reload()
      invitations.reload()
    } catch (cause) {
      setEraseError(cause instanceof Error ? cause.message : 'تعذّر حذف الحساب.')
    } finally {
      setErasingBusy(false)
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
                          <div className="flex items-center gap-1">
                            <Button
                              size="sm"
                              variant="ghost"
                              disabled={busyId === admin.user_id}
                              onClick={() => setRemoving(admin)}
                            >
                              <UserMinus size={13} aria-hidden />
                              سحب الصلاحية
                            </Button>
                            {admin.role === 'owner' ? null : (
                              <>
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  disabled={busyId === admin.user_id}
                                  onClick={() => openHandover(admin)}
                                  title="تُسلّمه اللوحة، وتنزل أنت إلى مدير"
                                >
                                  <Crown size={13} aria-hidden />
                                  نقل الملكية
                                </Button>
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  disabled={busyId === admin.user_id}
                                  onClick={() => openErase(admin)}
                                  title="يمحو حسابه من القاعدة، لا صلاحيته فقط"
                                  className="text-[var(--critical)]"
                                >
                                  <Trash2 size={13} aria-hidden />
                                  حذف الحساب
                                </Button>
                              </>
                            )}
                          </div>
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
              <p className="text-xs font-medium text-ink">دعوة موظف</p>
              {/*
                الدعوة لا إنشاء الحساب: إنشاء حساب مصادقة يحتاج مفتاح الخدمة،
                وهو يتجاوز RLS كلها فلا يُسلَّم لمتصفّح. والدعوة أسلم لا أضعف —
                الموظف يختار كلمة مروره بيده، فلا يعرفها المالك ولا تمرّ في رسالة.
              */}
              <p className="mt-0.5 text-[11px] leading-5 text-muted">
                اكتب بريده واختر دوره، فيخرج لك رمز تُرسله إليه. يفتح صفحة الدخول ويسجّل نفسه
                بالرمز، ويختار كلمة مروره بيده.
              </p>
            </div>

            <div className="flex flex-wrap items-end gap-2">
              <div className="min-w-52 flex-1">
                <Field label="بريد الموظف">
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
                {adding ? <Spinner /> : <UserPlus size={14} aria-hidden />}
                إنشاء دعوة
              </Button>
            </div>

            <p className="text-[11px] text-ink-2">{ROLE_DESCRIPTION[newRole]}</p>
          </form>
        ) : null}

        {canManageAdmins && (invitations.data ?? []).length > 0 ? (
          <div className="overflow-x-auto rounded-lg border border-hairline">
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr className="bg-surface-2">
                  {['الدعوة', 'الدور', 'الرمز', 'تنتهي', ''].map((heading, i) => (
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
                {(invitations.data ?? []).map((invitation) => (
                  <tr key={invitation.id} className="border-b border-hairline last:border-0">
                    <td dir="ltr" className="px-3 py-2 text-start whitespace-nowrap text-ink">
                      {invitation.email}
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap text-ink-2">
                      {ROLE_LABEL[invitation.role]}
                    </td>
                    <td className="px-3 py-2">
                      {invitation.status === 'pending' ? (
                        <button
                          type="button"
                          dir="ltr"
                          onClick={() => copyToken(invitation.token)}
                          title="انسخ الرمز"
                          className="tnum cursor-pointer rounded-md border border-hairline bg-surface px-2 py-1 font-medium tracking-widest text-ink hover:border-accent"
                        >
                          {invitation.token}
                        </button>
                      ) : (
                        <span className="text-muted">—</span>
                      )}
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      {invitation.status === 'pending' ? (
                        <span className="text-ink-2">{formatRelative(invitation.expires_at)}</span>
                      ) : (
                        <Badge tone={invitation.status === 'accepted' ? 'good' : 'neutral'}>
                          {invitation.status === 'accepted' ? 'قُبلت' : 'انتهت'}
                        </Badge>
                      )}
                    </td>
                    <td className="px-3 py-2">
                      {invitation.status === 'pending' ? (
                        <Button size="sm" variant="ghost" onClick={() => dropInvitation(invitation)}>
                          إلغاء
                        </Button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}

      </CardBody>

      <ConfirmDialog
        open={erasing !== null}
        title="حذف الحساب من القاعدة؟"
        message={
          `سيُمحى حساب ${erasing?.email ?? ''} نهائياً: صفّه في المسؤولين، ودعواته، ` +
          'وحساب دخوله نفسه. ولن يستطيع التسجيل بالبريد نفسه إلا من جديد. ' +
          'وإن كان له حسابٌ عميل على التطبيق فستمنع القاعدة الحذف حمايةً لحجوزاته — ' +
          'اسحب صلاحيته حينئذٍ بدل حذفه. اكتب بريده للتأكيد.'
        }
        confirmLabel="نعم، احذف الحساب"
        tone="danger"
        busy={erasingBusy}
        error={eraseError}
        confirmDisabled={
          typedErase.trim().toLowerCase() !== (erasing?.email ?? '').trim().toLowerCase()
        }
        onConfirm={confirmErase}
        onCancel={() => setErasing(null)}
      >
        <Field label="اكتب بريد الموظف للتأكيد">
          {(fieldId) => (
            <Input
              id={fieldId}
              dir="ltr"
              autoComplete="off"
              value={typedErase}
              onChange={(event) => setTypedErase(event.target.value)}
              placeholder={erasing?.email ?? ''}
            />
          )}
        </Field>
      </ConfirmDialog>

      <ConfirmDialog
        open={handover !== null}
        title="نقل ملكية اللوحة؟"
        message={
          `سيصير ${handover?.email ?? ''} مالك اللوحة، وتنزل أنت إلى «مدير» — ` +
          'تحتفظ بكل الصلاحيات عدا إدارة المسؤولين. ولا تستطيع استرداد الملكية ' +
          'بنفسك بعدها: المالك الجديد وحده يعيدها إليك. اكتب بريده للتأكيد.'
        }
        confirmLabel="نعم، انقل الملكية"
        tone="danger"
        busy={handingOver}
        error={handoverError}
        confirmDisabled={
          typedEmail.trim().toLowerCase() !== (handover?.email ?? '').trim().toLowerCase()
        }
        onConfirm={confirmHandover}
        onCancel={() => setHandover(null)}
      >
        <Field label="اكتب بريد المالك الجديد">
          {(fieldId) => (
            <Input
              id={fieldId}
              dir="ltr"
              autoComplete="off"
              value={typedEmail}
              onChange={(event) => setTypedEmail(event.target.value)}
              placeholder={handover?.email ?? ''}
            />
          )}
        </Field>
      </ConfirmDialog>

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
