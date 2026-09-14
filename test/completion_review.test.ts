// طابورُ اعتماد التنفيذ في اللوحة — `src/services/bookings.ts`.
//
// ── وما لا يقيسه هذا الملفّ ──────────────────────────────────────────────────
//
// **الحمايةُ في القاعدة لا هنا.** أنّ المزوّد لا يُتمّ حجزَه، وأنّ المحاسبَ
// لا يعتمد، وأنّ المستحقّات تزيد بالصافي — كلُّ ذلك محرزٌ في
// `supabase/completion_review.sql` ومقيسٌ في
// `supabase/tests/completion_review.test.mjs` مع ضوابطه السالبة. وشيفرةُ
// اللوحة تُنادى من متصفّحٍ يملك صاحبُه أدواتِ المطوّر، فحارسٌ هنا زينة.
//
// ── فما يُقاس هنا المرشِّحُ وحدَه ────────────────────────────────────────────
//
// **١) أنّ «قيد مراجعة التنفيذ» ليس حالةً في `status`** — بل «مؤكَّدٌ وطلب
//    صاحبُه الاعتماد». ومرشِّحٌ يُقارن `status === 'completion_review'` يردّ
//    قائمةً فارغةً أبداً، والمسؤولُ يظنّ أنّ لا طلبَ ينتظر بينما الطابورُ
//    يمتلئ.
// **٢) وأنّه لا يبتلع المؤكَّدة التي لا طلبَ عليها** — فيُعتمد ما لم يُطلب.
// **٣) وأنّ الردَّ بلا سببٍ يُرفض** قبل أن يبلغ الشبكةَ أصلاً.
import { describe, expect, it } from 'vitest'

// ومساراتٌ نسبيّةٌ كما في بقيّة `test/`: لا كنيةَ `@` في `vitest.config.ts`.
import type { Booking } from '../src/lib/types'
import { listBookings, rejectCompletion } from '../src/services/bookings'

const query = (status: Parameters<typeof listBookings>[0]['status']) => ({
  search: '',
  status,
  category: 'all' as const,
  governorate: 'all' as const,
  days: 'all' as const,
  page: 0,
  pageSize: 500,
})

describe('مرشِّحُ «قيد مراجعة التنفيذ»', () => {
  it('**يردّ حجوزاتٍ عليها طلبُ اعتماد** — لا قائمةً فارغة', async () => {
    const { rows } = await listBookings(query('completion_review'))
    expect(rows.length).toBeGreaterThan(0)
    expect(rows.every((b: Booking) => b.completion_requested_at !== null)).toBe(true)
  })

  it('**وكلُّها مؤكَّدةٌ لا منفَّذة** — الطلبُ ليس حالةً في status', async () => {
    const { rows } = await listBookings(query('completion_review'))
    expect(rows.every((b: Booking) => b.status === 'confirmed')).toBe(true)
  })

  it('**ولا يبتلع مؤكَّدةً لا طلبَ عليها**', async () => {
    const review = await listBookings(query('completion_review'))
    const confirmed = await listBookings(query('confirmed'))

    const waiting = confirmed.rows.filter((b: Booking) => b.completion_requested_at)
    const idle = confirmed.rows.filter((b: Booking) => !b.completion_requested_at)

    expect(idle.length).toBeGreaterThan(0)
    expect(review.rows.length).toBe(waiting.length)
  })

  it('و«مؤكَّد» يبقى يعرضها كلَّها — الطلبُ لا يُخرجها منه', async () => {
    const confirmed = await listBookings(query('confirmed'))
    expect(confirmed.rows.every((b: Booking) => b.status === 'confirmed')).toBe(true)
    expect(confirmed.rows.some((b: Booking) => b.completion_requested_at)).toBe(true)
  })
})

describe('وردُّ الطلب', () => {
  const booking = { id: 'x', reference: 'BK-1', provider_name: 'قاعة' } as Booking

  it('**بلا سببٍ يُرفض** — وإلّا دار الطابورُ على نفسه', async () => {
    await expect(rejectCompletion(booking, '   ')).rejects.toThrow('اكتب سببَ الردّ.')
  })
})
