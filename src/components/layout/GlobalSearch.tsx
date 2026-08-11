import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search } from 'lucide-react'
import { cn } from '@/lib/cn'
import { formatDate, formatMoney } from '@/lib/format'
import { mockBookings, mockPayments, mockProviders, mockUsers } from '@/data/mock'

interface Hit {
  id: string
  to: string
  kind: string
  title: string
  subtitle: string
}

/** Small enough to scan, large enough that an exact reference always appears. */
const LIMIT = 6

/**
 * One box for the three things support is handed over the phone: a booking
 * reference, a transaction reference, or somebody's name.
 *
 * The demo index is the local dataset. Against a live project this becomes one
 * RPC — the shape of the result list is what matters here.
 */
function search(term: string): Hit[] {
  const q = term.trim().toLowerCase()
  if (q.length < 2) return []

  const hits: Hit[] = []

  for (const booking of mockBookings) {
    if (hits.length >= LIMIT * 3) break
    if (
      booking.reference.toLowerCase().includes(q) ||
      booking.user_name.toLowerCase().includes(q) ||
      booking.service_title.toLowerCase().includes(q)
    ) {
      hits.push({
        id: booking.id,
        to: `/bookings/${booking.id}`,
        kind: 'حجز',
        title: booking.reference,
        subtitle: `${booking.user_name} · ${booking.provider_name} · ${formatDate(booking.event_date)}`,
      })
    }
  }

  for (const payment of mockPayments) {
    if (payment.reference.toLowerCase().includes(q)) {
      hits.push({
        id: payment.id,
        to: payment.booking_id ? `/bookings/${payment.booking_id}` : '/payments',
        kind: 'معاملة',
        title: payment.reference,
        subtitle: `${payment.user_name} · ${formatMoney(payment.amount)}`,
      })
    }
  }

  for (const provider of mockProviders) {
    if (
      provider.business_name.toLowerCase().includes(q) ||
      provider.full_name.toLowerCase().includes(q) ||
      provider.phone.includes(q)
    ) {
      hits.push({
        id: provider.id,
        to: `/providers/${provider.id}`,
        kind: 'مزوّد',
        title: provider.business_name || provider.full_name,
        subtitle: `${provider.categories.join('، ')} · ${provider.governorate}`,
      })
    }
  }

  for (const user of mockUsers) {
    if (
      user.full_name.toLowerCase().includes(q) ||
      user.email.toLowerCase().includes(q) ||
      user.phone.includes(q)
    ) {
      hits.push({
        id: user.id,
        to: `/users/${user.id}`,
        kind: 'عميل',
        title: user.full_name,
        subtitle: user.email,
      })
    }
  }

  return hits.slice(0, LIMIT)
}

export function GlobalSearch() {
  const navigate = useNavigate()
  const [term, setTerm] = useState('')
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const boxRef = useRef<HTMLDivElement | null>(null)

  const hits = useMemo(() => search(term), [term])

  useEffect(() => {
    setActive(0)
  }, [term])

  // A click anywhere else dismisses the panel; Escape does too, from the input.
  useEffect(() => {
    if (!open) return
    function onPointerDown(event: PointerEvent) {
      if (!boxRef.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('pointerdown', onPointerDown)
    return () => document.removeEventListener('pointerdown', onPointerDown)
  }, [open])

  function go(hit: Hit) {
    navigate(hit.to)
    setTerm('')
    setOpen(false)
  }

  return (
    <div ref={boxRef} className="relative hidden min-w-0 flex-1 sm:block sm:max-w-md">
      <Search
        size={15}
        aria-hidden
        className="pointer-events-none absolute top-1/2 start-3 -translate-y-1/2 text-muted"
      />
      <input
        type="search"
        role="combobox"
        aria-expanded={open && hits.length > 0}
        aria-controls="global-search-results"
        aria-label="بحث سريع"
        value={term}
        dir="auto"
        placeholder="بحث سريع عن مزوّد أو حجز أو رقم معاملة…"
        onChange={(event) => {
          setTerm(event.target.value)
          setOpen(true)
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={(event) => {
          if (event.key === 'Escape') {
            setOpen(false)
            return
          }
          if (hits.length === 0) return
          if (event.key === 'ArrowDown') {
            event.preventDefault()
            setActive((index) => (index + 1) % hits.length)
          }
          if (event.key === 'ArrowUp') {
            event.preventDefault()
            setActive((index) => (index - 1 + hits.length) % hits.length)
          }
          if (event.key === 'Enter') {
            event.preventDefault()
            go(hits[active])
          }
        }}
        className="h-9 w-full rounded-lg border border-hairline bg-surface-2 ps-9 pe-3 text-sm text-ink placeholder:text-muted focus:border-accent"
      />

      {open && term.trim().length >= 2 ? (
        <div
          id="global-search-results"
          role="listbox"
          className="absolute top-11 start-0 z-40 w-full overflow-hidden rounded-xl border border-hairline bg-surface shadow-lg"
        >
          {hits.length === 0 ? (
            <p className="px-3 py-3 text-xs text-muted">لا نتائج مطابقة.</p>
          ) : (
            <ul>
              {hits.map((hit, index) => (
                <li key={`${hit.kind}-${hit.id}`}>
                  <button
                    type="button"
                    role="option"
                    aria-selected={index === active}
                    onPointerEnter={() => setActive(index)}
                    onClick={() => go(hit)}
                    className={cn(
                      'flex w-full items-center justify-between gap-3 px-3 py-2 text-start',
                      index === active ? 'bg-surface-2' : 'bg-transparent',
                    )}
                  >
                    <span className="min-w-0">
                      <span className="block truncate text-xs font-medium text-ink">
                        {hit.title}
                      </span>
                      <span className="block truncate text-[11px] text-muted">{hit.subtitle}</span>
                    </span>
                    <span className="shrink-0 rounded-full border border-hairline px-2 py-0.5 text-[10px] text-muted">
                      {hit.kind}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}
    </div>
  )
}
