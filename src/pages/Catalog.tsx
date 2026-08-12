import { useCallback, useEffect, useState } from 'react'
import { Search } from 'lucide-react'
import { Badge } from '@/components/ui/Badge'
import { Card, CardBody, CardHeader } from '@/components/ui/Card'
import { EmptyState, ErrorState, LoadingBlock, Toast } from '@/components/ui/Feedback'
import { Input, Select, Toggle } from '@/components/ui/Field'
import { Pagination } from '@/components/ui/Pagination'
import { useAuth } from '@/context/AuthContext'
import { useAsync } from '@/hooks/useAsync'
import { useDebounced } from '@/hooks/useDebounced'
import { cn } from '@/lib/cn'
import { formatDuration, formatMoney, formatNumber } from '@/lib/format'
import type { ProviderService } from '@/lib/types'
import {
  describeRule,
  listCategories,
  listPolicies,
  listServices,
  setCategoryActive,
  setServiceActive,
} from '@/services/catalog'

const PAGE_SIZE = 10

type Tab = 'categories' | 'services' | 'policies'

const TABS: { value: Tab; label: string }[] = [
  { value: 'categories', label: 'الأقسام' },
  { value: 'services', label: 'الخدمات المعروضة' },
  { value: 'policies', label: 'سياسات الإلغاء' },
]

export function CatalogPage() {
  const [tab, setTab] = useState<Tab>('categories')
  const [toast, setToast] = useState<string | null>(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(timer)
  }, [toast])

  return (
    <div className="flex flex-col gap-4">
      <div role="tablist" aria-label="أقسام الكتالوج" className="flex flex-wrap gap-1.5">
        {TABS.map((entry) => (
          <button
            key={entry.value}
            type="button"
            role="tab"
            aria-selected={tab === entry.value}
            onClick={() => setTab(entry.value)}
            className={cn(
              'h-9 cursor-pointer rounded-lg border px-3 text-xs font-medium transition-colors',
              tab === entry.value
                ? 'border-transparent bg-accent text-accent-ink'
                : 'border-hairline bg-surface text-ink-2 hover:bg-surface-2 hover:text-ink',
            )}
          >
            {entry.label}
          </button>
        ))}
      </div>

      {tab === 'categories' ? <CategoriesTab onToast={setToast} /> : null}
      {tab === 'services' ? <ServicesTab onToast={setToast} /> : null}
      {tab === 'policies' ? <PoliciesTab /> : null}

      {toast ? <Toast message={toast} /> : null}
    </div>
  )
}

// ---------------------------------------------------------------------------

function CategoriesTab({ onToast }: { onToast: (message: string) => void }) {
  const { can } = useAuth()
  const canWrite = can('catalog')
  const [busyId, setBusyId] = useState<string | null>(null)
  const { data, error, loading, refetching, reload } = useAsync(listCategories, [])

  async function toggle(id: string, name: string, next: boolean) {
    const category = data?.find((entry) => entry.id === id)
    if (!category) return
    setBusyId(id)
    try {
      await setCategoryActive(category, next)
      onToast(next ? `فُعّل قسم «${name}».` : `عُطّل قسم «${name}».`)
      reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusyId(null)
    }
  }

  if (loading) return <Card><LoadingBlock /></Card>
  if (error && !data) return <Card><ErrorState message={error} onRetry={reload} /></Card>

  return (
    <div className={cn('grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3', refetching && 'is-refetching')}>
      {(data ?? []).map((category) => (
        <Card key={category.id}>
          <CardHeader
            title={category.name}
            subtitle={
              <span dir="ltr" className="block text-start">
                {category.slug}
              </span>
            }
            actions={
              <Badge tone={category.is_active ? 'good' : 'neutral'}>
                {category.is_active ? 'مفعّل' : 'معطّل'}
              </Badge>
            }
          />
          <CardBody className="flex flex-col gap-3">
            <p className="text-xs leading-6 text-ink-2">{category.description}</p>

            <p className="tnum text-xs text-muted">
              {formatNumber(category.providers_count ?? 0)} مقدّم خدمة موثّق
            </p>

            {category.custom_fields.length > 0 ? (
              <div>
                <p className="text-xs font-medium text-ink">حقول خاصة بالقسم</p>
                <ul className="mt-1 flex flex-wrap gap-1.5">
                  {category.custom_fields.map((field) => (
                    <li
                      key={field.key}
                      className="rounded-full border border-hairline px-2 py-0.5 text-[11px] text-ink-2"
                      title={field.required ? 'حقل إلزامي' : 'حقل اختياري'}
                    >
                      {field.label}
                      {field.required ? ' *' : ''}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            <Toggle
              checked={category.is_active}
              disabled={!canWrite || busyId === category.id}
              onChange={(next) => toggle(category.id, category.name, next)}
              label="متاح في التطبيق"
              description="تعطيل القسم يخفيه عن العملاء ولا يمسّ الحجوزات القائمة."
            />
          </CardBody>
        </Card>
      ))}
    </div>
  )
}

// ---------------------------------------------------------------------------

function ServicesTab({ onToast }: { onToast: (message: string) => void }) {
  const { canWrite } = useAuth()
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<string | 'all'>('all')
  const [active, setActive] = useState<'all' | 'active' | 'inactive'>('all')
  const [page, setPage] = useState(0)
  const [busyId, setBusyId] = useState<string | null>(null)

  const debouncedSearch = useDebounced(search)
  const categories = useAsync(listCategories, [])

  useEffect(() => {
    setPage(0)
  }, [debouncedSearch, category, active])

  const load = useCallback(
    () => listServices({ search: debouncedSearch, category, active, page, pageSize: PAGE_SIZE }),
    [debouncedSearch, category, active, page],
  )
  const { data, error, loading, refetching, reload } = useAsync(load, [
    debouncedSearch,
    category,
    active,
    page,
  ])

  async function toggle(service: ProviderService, next: boolean) {
    setBusyId(service.id)
    try {
      await setServiceActive(service, next)
      onToast(next ? 'عُرضت الخدمة في التطبيق.' : 'أُخفيت الخدمة عن التطبيق.')
      reload()
    } catch (cause) {
      onToast(cause instanceof Error ? cause.message : 'تعذّر تنفيذ الإجراء.')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-56 flex-1">
          <Search
            size={15}
            aria-hidden
            className="pointer-events-none absolute top-1/2 start-3 -translate-y-1/2 text-muted"
          />
          <Input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="ابحث باسم الخدمة أو مقدّمها…"
            aria-label="بحث في الخدمات"
            className="ps-9"
          />
        </div>

        <div className="w-40">
          <Select
            value={category}
            onChange={(event) => setCategory(event.target.value)}
            aria-label="تصفية حسب القسم"
          >
            <option value="all">كل الأقسام</option>
            {(categories.data ?? []).map((entry) => (
              <option key={entry.id} value={entry.name}>
                {entry.name}
              </option>
            ))}
          </Select>
        </div>

        <div className="w-36">
          <Select
            value={active}
            onChange={(event) => setActive(event.target.value as 'all' | 'active' | 'inactive')}
            aria-label="تصفية حسب العرض"
          >
            <option value="all">الكل</option>
            <option value="active">معروضة</option>
            <option value="inactive">مخفية</option>
          </Select>
        </div>
      </div>

      <Card className={cn('overflow-hidden', refetching && 'is-refetching')}>
        {loading ? (
          <LoadingBlock />
        ) : error && !data ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data || data.rows.length === 0 ? (
          <EmptyState title="لا توجد خدمات" description="جرّب تعديل البحث أو عوامل التصفية." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="bg-surface-2">
                  {['الخدمة', 'القسم', 'السعر', 'العربون', 'المدة', 'سياسة الإلغاء', 'العرض'].map(
                    (heading) => (
                      <th
                        key={heading}
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
                {data.rows.map((service) => (
                  <tr
                    key={service.id}
                    className="border-b border-hairline last:border-0 hover:bg-surface-2"
                  >
                    <td className="px-4 py-3">
                      <p className="text-xs font-medium text-ink">{service.title}</p>
                      <p className="text-[11px] text-muted">{service.provider_name}</p>
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {service.category_name}
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {service.price_to
                        ? `${formatMoney(service.price)} — ${formatMoney(service.price_to)}`
                        : formatMoney(service.price)}
                      <span className="block text-[11px] text-muted">لكل {service.unit}</span>
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {service.deposit_percent}%
                    </td>
                    <td className="tnum px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {formatDuration(service.duration_minutes * 60)}
                    </td>
                    <td className="px-4 py-3 text-xs whitespace-nowrap text-ink-2">
                      {service.cancellation_policy_name || '—'}
                    </td>
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        disabled={!canWrite || busyId === service.id}
                        onClick={() => toggle(service, !service.is_active)}
                        title={canWrite ? undefined : 'دورك الحالي للقراءة فقط'}
                        className="cursor-pointer disabled:cursor-not-allowed disabled:opacity-55"
                      >
                        <Badge tone={service.is_active ? 'good' : 'neutral'}>
                          {service.is_active ? 'معروضة' : 'مخفية'}
                        </Badge>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {data && data.rows.length > 0 ? (
          <Pagination page={page} pageSize={PAGE_SIZE} total={data.total} onChange={setPage} />
        ) : null}
      </Card>
    </div>
  )
}

// ---------------------------------------------------------------------------

function PoliciesTab() {
  const { data, error, loading, reload } = useAsync(listPolicies, [])

  if (loading) return <Card><LoadingBlock /></Card>
  if (error && !data) return <Card><ErrorState message={error} onRetry={reload} /></Card>

  return (
    <div className="flex flex-col gap-4">
      <p className="rounded-lg border border-hairline bg-surface-2 px-3 py-2.5 text-xs leading-6 text-ink-2">
        كل حجز ينسخ سلّم الإلغاء لحظة إنشائه، فتعديل السياسة هنا يسري على الحجوزات
        الجديدة فقط ولا يغيّر ما اتُّفق عليه في حجز قائم.
      </p>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {(data ?? []).map((policy) => (
          <Card key={policy.id}>
            <CardHeader
              title={policy.name}
              actions={
                policy.is_default ? <Badge tone="good">الافتراضية</Badge> : null
              }
            />
            <CardBody className="flex flex-col gap-3">
              <p className="text-xs leading-6 text-ink-2">{policy.description}</p>
              <ul className="flex flex-col gap-1 text-xs text-ink">
                {policy.rules.map((rule) => (
                  <li key={rule.hours_before} className="flex items-center gap-2">
                    <span
                      aria-hidden
                      className="h-1.5 w-1.5 shrink-0 rounded-full"
                      style={{
                        background:
                          rule.refund_percent >= 75
                            ? 'var(--good)'
                            : rule.refund_percent > 0
                              ? 'var(--warning)'
                              : 'var(--critical)',
                      }}
                    />
                    {describeRule(rule)}
                  </li>
                ))}
              </ul>
            </CardBody>
          </Card>
        ))}
      </div>
    </div>
  )
}
