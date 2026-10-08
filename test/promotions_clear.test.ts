// «تفريغ المنتهية» — «اريد زر تفريغ خاص للمدير»، واختار صاحبُ المنصّة (أ أ):
// المنتهيةُ والملغاةُ وحدها، والمالكُ وحده. والقاعدةُ هي الحَكَم فيما يُحذف ومَن
// يحذف (`supabase/tests/promotions_clear.test.mjs`)؛ وما هنا يقيس ما تعدّه
// اللوحةُ وتحذفه في وضع العرض، وأنّ صورَ اللافتات تُعرف بأسمائها في السلّة.
import { describe, expect, it } from 'vitest'

import {
  bannerPathOf,
  clearEndedPromotions,
  countClearablePromotions,
  isClearable,
  listPromotions,
  promotionTiming,
} from '../src/services/growth'

const NOW = new Date('2026-10-08T12:00:00Z')
const at = (hours: number) => new Date(NOW.getTime() + hours * 3_600_000).toISOString()

describe('تفريغ المنتهية', () => {
  it('**يُفرَّغ المنتهي والملغى، وما انقضى وعمودُه «جارية»**', () => {
    expect(isClearable({ status: 'ended', ends_at: at(-48) }, NOW)).toBe(true)
    expect(isClearable({ status: 'cancelled', ends_at: at(48) }, NOW)).toBe(true)
    expect(isClearable({ status: 'active', ends_at: at(-1) }, NOW)).toBe(true)
  })

  it('**والجاريةُ والمجدولةُ لا تُمسّ** — ولو قاربت نهايتها', () => {
    expect(isClearable({ status: 'active', ends_at: at(5) }, NOW)).toBe(false)
    expect(isClearable({ status: 'scheduled', ends_at: at(24 * 30) }, NOW)).toBe(false)
  })

  it('**وصورةُ اللافتة تُعرف باسمها في السلّة** — وما ليس منها لا يُحذف', () => {
    expect(
      bannerPathOf('https://abc.supabase.co/storage/v1/object/public/ad-banners/banner-17%20a.webp?v=2'),
    ).toBe('banner-17 a.webp')
    expect(bannerPathOf('https://abc.supabase.co/storage/v1/object/public/category-images/x.webp')).toBeNull()
    expect(bannerPathOf('https://example.com/a.webp')).toBeNull()
  })

  it('**وفي وضع العرض: يُعدّ ما يُحذف، ويُحذف هو وحده**', async () => {
    const all = async () =>
      (await listPromotions({ search: '', status: 'all', kind: 'all', page: 0, pageSize: 100 })).rows
    const before = await all()
    const expected = before.filter((p) => isClearable(p)).length
    expect(expected).toBeGreaterThan(0)
    expect(await countClearablePromotions()).toBe(expected)

    const { deleted } = await clearEndedPromotions()
    expect(deleted).toBe(expected)

    const after = await all()
    expect(after).toHaveLength(before.length - expected)
    expect(after.every((p) => ['active', 'scheduled'].includes(promotionTiming(p).status))).toBe(true)
    expect(await countClearablePromotions()).toBe(0)
  })
})
