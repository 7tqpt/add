import { useEffect, useMemo, useState } from 'react'
import { Plus, Ticket } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { ConfirmDialog } from '@/components/ui/ConfirmDialog'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Field, Input, Select } from '@/components/ui/Field'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney, formatNumber, formatPercent } from '@/lib/format'
import type { Coupon, CouponKind } from '@/lib/types'
import { errorText } from '@/services/base'
import { listCategories } from '@/services/catalog'
import {
  COUPON_KIND_LABEL,
  couponState,
  createCoupon,
  listCoupons,
  setCouponActive,
} from '@/services/coupons'
import { getSettings } from '@/services/settings'

export function CouponsPage() {
  const { can } = useAuth()
  const canWrite = can('finance')
  const [toast, setToast] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [pending, setPending] = useState<{ coupon: Coupon; next: boolean } | null>(null)
  const [busy, setBusy] = useState(false)

  const { data, error, loading, refetching, reload } = useAsync(listCoupons, [])
  const settings = useAsync(getSettings, [])

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  const spent = useMemo(
    () => (data ?? []).reduce((total, coupon) => total + coupon.total_discount, 0),
    [data],
  )

  async function toggle() {
    if (!pending) return
    setBusy(true)
    try {
      await setCouponActive(pending.coupon, pending.next)
      setToast(
        pending.next
          ? `عاد كود «${pending.coupon.code}» يعمل.`
          : `أُوقف كود «${pending.coupon.code}».`,
      )
      setPending(null)
      reload()
    } catch (cause) {
      setToast(errorText(cause, 'تعذّر تنفيذ الإجراء.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-col gap-5">
      {/* ── ما تُنفقه الحملات ───────────────────────────────────────────────
          والرقمُ في رأس الصفحة لا في آخرها: الكوبون **مصروف** لا إيراد،
          وعمولةُ المنصّة هي ما ينقص به. فمن يفتح الصفحة يجب أن يرى الكلفة
          قبل أن يرى زرَّ «كود جديد». */}
      <Card>
        <CardBody className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-lg bg-accent/10 text-accent">
              <Ticket size={20} aria-hidden />
            </span>
            <div>
              <p className="text-xs text-muted">ما خصمته الأكواد حتى الآن</p>
              <p className="tnum text-lg font-semibold text-ink">{formatMoney(spent)}</p>
            </div>
          </div>
          <p className="max-w-md text-xs leading-6 text-muted">
            الخصمُ يُطرح من <strong className="text-ink-2">عمولة المنصّة</strong> لا من مال مقدّم
            الخدمة، فيخرج بنصيبه كأن لم يكن كوبون. ولذلك لا يتجاوز الخصمُ العمولةَ
            {settings.data ? ` (${formatPercent(settings.data.commission_percent / 100)})` : ''}
            {' '}— والمنصّةُ لا تُعطي ما لا تملك.
          </p>
          <Button
            disabled={!canWrite}
            title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
            onClick={() => setCreating(true)}
          >
            <Plus size={16} aria-hidden />
            كود جديد
          </Button>
        </CardBody>
      </Card>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        <CardHeader title="أكواد الخصم" subtitle="ما يكتبه العميل في شاشة الحجز." />
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.length === 0 ? (
          <EmptyState
            title="لا أكواد بعد"
            description="أنشئ كوداً لحملةٍ موسمية أو لإطلاق قسمٍ جديد."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="glass-item">
                  {['الكود', 'الخصم', 'الشروط', 'الفترة', 'الاستعمال', 'ما كلّف', 'الحالة', ''].map(
                    (heading, index) => (
                      <th
                        key={index}
                        scope="col"
                        className="border-b border-hairline px-4 py-2.5 text-start text-xs font-medium whitespace-nowrap text-ink-2"
                      >
                        {heading}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody>
                {data.map((coupon) => {
                  const state = couponState(coupon)
                  return (
                    <tr key={coupon.id} className="glass-row border-b border-hairline last:border-0">
                      <td className="px-4 py-3">
                        <p className="font-mono text-xs font-semibold text-ink">{coupon.code}</p>
                        {coupon.description ? (
                          <p className="text-[11px] text-muted">{coupon.description}</p>
                        ) : null}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {coupon.kind === 'percent'
                          ? `${formatNumber(coupon.value)}٪`
                          : formatMoney(coupon.value)}
                        {coupon.kind === 'percent' && coupon.max_discount > 0 ? (
                          <span className="block text-[11px] text-muted">
                            بحدّ أقصى {formatMoney(coupon.max_discount)}
                          </span>
                        ) : null}
                      </td>
                      <td className="px-4 py-3 text-xs text-ink-2">
                        {coupon.min_total > 0 ? (
                          <span className="block whitespace-nowrap">
                            من {formatMoney(coupon.min_total)}
                          </span>
                        ) : null}
                        <span className="block text-[11px] text-muted">
                          {coupon.category_name ?? 'كل الأقسام'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatDate(coupon.starts_at)}
                        {/* بلا نهايةٍ يعني بلا نهاية — لا تاريخاً مخترعاً. */}
                        {coupon.ends_at ? ` — ${formatDate(coupon.ends_at)}` : ' — بلا نهاية'}
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatNumber(coupon.redemptions)}
                        <span className="block text-[11px] text-muted">
                          {coupon.max_uses > 0 ? `من ${formatNumber(coupon.max_uses)}` : 'بلا حدّ'}
                        </span>
                      </td>
                      <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                        {formatMoney(coupon.total_discount)}
                      </td>
                      <td className="px-4 py-3">
                        <Badge tone={state.tone}>{state.label}</Badge>
                      </td>
                      <td className="px-4 py-3 text-end">
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={!canWrite}
                          title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                          onClick={() => setPending({ coupon, next: !coupon.is_active })}
                        >
                          {coupon.is_active ? 'إيقاف' : 'تشغيل'}
                        </Button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {creating ? (
        <NewCouponDialog
          onClose={() => setCreating(false)}
          onDone={(message) => {
            setCreating(false)
            setToast(message)
            reload()
          }}
        />
      ) : null}

      <ConfirmDialog
        open={pending !== null}
        title={pending?.next ? 'تشغيل الكود؟' : 'إيقاف الكود؟'}
        message={
          pending?.next
            ? `سيعود «${pending.coupon.code}» قابلاً للاستعمال في التطبيق.`
            : `لن يقبل التطبيق «${pending?.coupon.code}» بعد الآن. والحجوزاتُ التي استعملته لا تتأثّر.`
        }
        confirmLabel={pending?.next ? 'تشغيل' : 'إيقاف'}
        tone={pending?.next ? 'primary' : 'danger'}
        busy={busy}
        onCancel={() => setPending(null)}
        onConfirm={toggle}
      />

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

// ---------------------------------------------------------------------------

function NewCouponDialog({
  onClose,
  onDone,
}: {
  onClose: () => void
  onDone: (message: string) => void
}) {
  const categories = useAsync(listCategories, [])
  const [code, setCode] = useState('')
  const [description, setDescription] = useState('')
  const [kind, setKind] = useState<CouponKind>('percent')
  const [value, setValue] = useState('10')
  const [maxDiscount, setMaxDiscount] = useState('0')
  const [minTotal, setMinTotal] = useState('0')
  const [categoryId, setCategoryId] = useState('')
  const [endsAt, setEndsAt] = useState('')
  const [maxUses, setMaxUses] = useState('0')
  const [perUser, setPerUser] = useState('1')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit() {
    const trimmed = code.trim().toUpperCase()
    if (!trimmed) {
      setError('اكتب الكود.')
      return
    }
    const amount = Number(value)
    if (!Number.isFinite(amount) || amount <= 0) {
      setError('قيمة الخصم رقمٌ أكبر من صفر.')
      return
    }
    // النسبةُ فوق المئة ليست خصماً بل هديّة — والقاعدة تردّها، لكنّ الردَّ هنا
    // أسرعُ وأوضحُ من رسالة قيدٍ في Postgres.
    if (kind === 'percent' && amount > 100) {
      setError('النسبة لا تتجاوز ١٠٠٪.')
      return
    }

    setBusy(true)
    setError(null)
    try {
      await createCoupon({
        code: trimmed,
        description: description.trim(),
        kind,
        value: amount,
        max_discount: Number(maxDiscount) || 0,
        min_total: Number(minTotal) || 0,
        category_id: categoryId || null,
        starts_at: new Date().toISOString(),
        // حقلٌ فارغٌ يعني **بلا نهاية**، لا تاريخاً في الماضي ولا اليوم.
        ends_at: endsAt ? new Date(`${endsAt}T23:59:59`).toISOString() : null,
        max_uses: Number(maxUses) || 0,
        max_uses_per_user: Number(perUser) || 0,
      })
      onDone(`أُنشئ كود «${trimmed}».`)
    } catch (cause) {
      setError(errorText(cause, 'تعذّر إنشاء الكود.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center bg-ink/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="كود خصم جديد"
    >
      <Card className="max-h-[90vh] w-full max-w-lg overflow-y-auto">
        <CardHeader title="كود خصم جديد" subtitle="الخصمُ من عمولة المنصّة." />
        <CardBody className="flex flex-col gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="الكود" hint="بحروفٍ لاتينية وأرقام">
              {(id) => (
                <Input
                  id={id}
                  value={code}
                  onChange={(event) => setCode(event.target.value.toUpperCase())}
                  placeholder="EID25"
                  className="font-mono"
                />
              )}
            </Field>
            <Field label="الوصف">
              {(id) => (
                <Input
                  id={id}
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="حملة العيد"
                />
              )}
            </Field>
            <Field label="النوع">
              {(id) => (
                <Select
                  id={id}
                  value={kind}
                  onChange={(event) => setKind(event.target.value as CouponKind)}
                >
                  {(Object.keys(COUPON_KIND_LABEL) as CouponKind[]).map((key) => (
                    <option key={key} value={key}>
                      {COUPON_KIND_LABEL[key]}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label={kind === 'percent' ? 'النسبة ٪' : 'المبلغ بالريال'}>
              {(id) => (
                <Input
                  id={id}
                  type="number"
                  min={1}
                  value={value}
                  onChange={(event) => setValue(event.target.value)}
                />
              )}
            </Field>
            {kind === 'percent' ? (
              <Field label="سقف الخصم" hint="صفر = بلا سقف">
                {(id) => (
                  <Input
                    id={id}
                    type="number"
                    min={0}
                    value={maxDiscount}
                    onChange={(event) => setMaxDiscount(event.target.value)}
                  />
                )}
              </Field>
            ) : null}
            <Field label="أقل إجمالي حجز" hint="صفر = بلا شرط">
              {(id) => (
                <Input
                  id={id}
                  type="number"
                  min={0}
                  value={minTotal}
                  onChange={(event) => setMinTotal(event.target.value)}
                />
              )}
            </Field>
            <Field label="القسم">
              {(id) => (
                <Select
                  id={id}
                  value={categoryId}
                  onChange={(event) => setCategoryId(event.target.value)}
                >
                  <option value="">كل الأقسام</option>
                  {(categories.data ?? []).map((category) => (
                    <option key={category.id} value={category.id}>
                      {category.name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label="ينتهي في" hint="فارغ = بلا نهاية">
              {(id) => (
                <Input
                  id={id}
                  type="date"
                  value={endsAt}
                  onChange={(event) => setEndsAt(event.target.value)}
                />
              )}
            </Field>
            <Field label="عدد الاستعمالات" hint="صفر = بلا حدّ">
              {(id) => (
                <Input
                  id={id}
                  type="number"
                  min={0}
                  value={maxUses}
                  onChange={(event) => setMaxUses(event.target.value)}
                />
              )}
            </Field>
            <Field label="لكل عميل" hint="صفر = بلا حدّ">
              {(id) => (
                <Input
                  id={id}
                  type="number"
                  min={0}
                  value={perUser}
                  onChange={(event) => setPerUser(event.target.value)}
                />
              )}
            </Field>
          </div>

          {error ? <p className="text-xs text-critical">{error}</p> : null}

          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={onClose} disabled={busy}>
              إلغاء
            </Button>
            <Button onClick={submit} disabled={busy}>
              {busy ? 'يُنشأ…' : 'إنشاء'}
            </Button>
          </div>
        </CardBody>
      </Card>
    </div>
  )
}
