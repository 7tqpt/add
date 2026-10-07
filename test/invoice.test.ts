// رقمُ الفاتورة جنب رقم الحجز — «اريد رقم فاتورة للكل حجز عشن اقدر اعرف جنب
// رقم الحجز»، واختار صاحبُ المنصّة أن يتبع رقمَ الحجز (`coupons.sql`).
import { describe, expect, it } from 'vitest'

import { invoiceLine, invoiceToBookingTerm, listBookings } from '../src/services/bookings'

describe('رقمُ الفاتورة', () => {
  it('**يُكتب تحت الحجز رقمُ فاتورته، أو «تصدر عند التأكيد» لما ينتظر المزوّد**', () => {
    expect(invoiceLine({ invoice_number: 'INV-2026-7F3A21C9', status: 'confirmed' })).toBe('INV-2026-7F3A21C9')
    expect(invoiceLine({ invoice_number: null, status: 'pending_provider' })).toBe('الفاتورة: تصدر عند التأكيد')
    expect(invoiceLine({ invoice_number: null, status: 'cancelled' })).toBeNull()
  })

  it('**ورقمُ الفاتورة يُبحث به كرقم الحجز**', () => {
    expect(invoiceToBookingTerm('INV-2026-7F3A21C9')).toBe('BK-2026-7F3A21C9')
    expect(invoiceToBookingTerm('inv-2026-000070')).toBe('BK-2026-000070')
    expect(invoiceToBookingTerm('بلقيس')).toBe('بلقيس')
  })

  it('**وفي وضع التجربة: كلُّ حجزٍ مؤكَّدٍ فاتورتُه بذيل رقمه، ولا فاتورةَ لما ينتظر**', async () => {
    const { rows } = await listBookings({
      search: '', status: 'all', category: 'all', governorate: 'all', days: 'all', page: 0, pageSize: 500,
    })
    const confirmed = rows.filter((b) => b.status === 'confirmed')
    expect(confirmed.length).toBeGreaterThan(0)
    for (const b of confirmed) expect(b.invoice_number).toBe(b.reference.replace(/^BK-/, 'INV-'))
    for (const b of rows.filter((r) => r.status === 'pending_provider')) expect(b.invoice_number).toBeNull()
    const found = await listBookings({
      search: confirmed[0].invoice_number!, status: 'all', category: 'all', governorate: 'all', days: 'all',
      page: 0, pageSize: 50,
    })
    expect(found.rows.map((b) => b.id)).toContain(confirmed[0].id)
  })
})
