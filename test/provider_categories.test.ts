// أقسامُ مقدّم الخدمة وموافقةُ الإدارة — اختار صاحبُ المنصّة (ج): يختار المزوّدُ أيَّ
// قسم، وما ليس من أقسامه ينتظر؛ والإدارةُ توافق بإضافة القسم له أو على الخدمة
// وحدَها أو ترفض بسبب. والقاعدةُ هي الحَكَم
// (`supabase/tests/provider_category_lock.test.mjs`)؛ وما هنا يقيس ما تعرضه
// اللوحةُ وتحفظه في وضع العرض — بقاعدة القاعدة نفسِها.
import { describe, expect, it } from 'vitest'

import {
  getProvider,
  isOutsideCategories,
  listServiceReviews,
  reviewService,
  setProviderCategories,
} from '../src/services/directory'
import { mockCategories, mockServices } from '../src/data/mock'

const odd = mockServices.find((s) => s.id === 'svc_0_1')!
const photo = mockCategories.find((c) => c.name === 'التصوير والإضاءة')!

describe('أقسامُ مقدّم الخدمة وموافقةُ الإدارة', () => {
  it('الخدمةُ خارج أقسام صاحبها تُعرف — وما في أقسامه لا', () => {
    const provider = { categories: ['القاعات والخيام'] }
    expect(isOutsideCategories({ category_name: 'التصوير والإضاءة' }, provider)).toBe(true)
    expect(isOutsideCategories({ category_name: 'القاعات والخيام' }, provider)).toBe(false)
  })

  it('**وما ليس من أقسامه ينتظر — مع أقسام صاحبه مكتوبة**', async () => {
    const reviews = await listServiceReviews()
    const row = reviews.find((r) => r.id === odd.id)
    expect(row?.approval).toBe('pending')
    expect(row?.category_name).toBe('التصوير والإضاءة')
    expect(row?.provider_categories).toBe('القاعات والخيام')
    // وما في أقسام أصحابه لا ينتظر شيئاً.
    expect(reviews.every((r) => r.category_name !== r.provider_categories)).toBe(true)
  })

  it('**والرفضُ بسبب — وبلا سببٍ لا يُرفض**', async () => {
    const row = (await listServiceReviews()).find((r) => r.id === odd.id)!
    await expect(reviewService(row, false, '  ')).rejects.toThrow('سبب الرفض')
    await reviewService(row, false, 'خارج نشاط القاعة')
    const after = (await listServiceReviews()).find((r) => r.id === odd.id)
    expect(after?.approval).toBe('rejected')
    expect(after?.approval_note).toBe('خارج نشاط القاعة')
  })

  it('**وإضافةُ قسمها له تقبلها — ولو كانت مرفوضة**', async () => {
    const provider = (await getProvider(odd.provider_id))!
    const own = mockCategories.filter((c) => provider.categories.includes(c.name))
    const { hidden } = await setProviderCategories(provider, [...own, photo])
    expect(hidden).toBe(0)
    expect((await listServiceReviews()).some((r) => r.id === odd.id)).toBe(false)

    // وحذفُه يُعيدها للمراجعة.
    const back = await setProviderCategories((await getProvider(odd.provider_id))!, own)
    expect(back.hidden).toBe(1)
    expect((await listServiceReviews()).find((r) => r.id === odd.id)?.approval).toBe('pending')
  })

  it('**والموافقةُ عليها بعينها تُخرجها من القائمة — وتضيف قسمَها لأقسام صاحبها** (ب)', async () => {
    // «ليش عن المزود جالس يظهر الملبوسات وفي الاصل تم تغيير القسم الي طباعة».
    const row = (await listServiceReviews()).find((r) => r.id === odd.id)!
    await reviewService(row, true)
    expect((await listServiceReviews()).some((r) => r.id === odd.id)).toBe(false)
    const categories = (await getProvider(odd.provider_id))!.categories
    expect(categories).toContain('التصوير والإضاءة')
    expect(categories).toContain('القاعات والخيام')
  })

  it('ولا يُترك بلا قسم', async () => {
    const provider = (await getProvider(mockServices[0].provider_id))!
    await expect(setProviderCategories(provider, [])).rejects.toThrow('قسماً واحداً على الأقلّ')
  })
})
