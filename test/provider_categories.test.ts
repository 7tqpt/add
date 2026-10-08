// أقسامُ مقدّم الخدمة — اختار صاحبُ المنصّة (أ ب): الإدارةُ تضبطها من صفحته، وخدماتُه
// خارجها مخفيّةٌ عن العملاء حتى تُراجَع. والقاعدةُ هي الحَكَم
// (`supabase/tests/provider_category_lock.test.mjs`)؛ وما هنا يقيس ما تعدّه
// اللوحةُ مخفيّاً وما تحفظه في وضع العرض.
import { describe, expect, it } from 'vitest'

import {
  getProvider,
  getProviderPortfolio,
  isOutsideCategories,
  setProviderCategories,
} from '../src/services/directory'
import { mockCategories, mockServices } from '../src/data/mock'

describe('أقسامُ مقدّم الخدمة', () => {
  it('**الخدمةُ خارج أقسام صاحبها تُعدّ مخفيّة** — وما في أقسامه لا', () => {
    const provider = { categories: ['القاعات والخيام'] }
    expect(isOutsideCategories({ category_name: 'التصوير والإضاءة' }, provider)).toBe(true)
    expect(isOutsideCategories({ category_name: 'القاعات والخيام' }, provider)).toBe(false)
    expect(isOutsideCategories({ category_name: 'التصوير والإضاءة' }, { categories: ['القاعات والخيام', 'التصوير والإضاءة'] })).toBe(false)
  })

  it('**وفي وضع العرض خدمةٌ خارج قسم صاحبها** — لتُرى في الصفحة', () => {
    const odd = mockServices.find((s) => s.id === 'svc_0_1')!
    expect(odd.category_name).toBe('التصوير والإضاءة')
  })

  it('**وإضافةُ قسمها له تعيدها، ويُعدّ ما بقي خارجها**', async () => {
    const odd = mockServices.find((s) => s.id === 'svc_0_1')!
    const provider = (await getProvider(odd.provider_id))!
    const own = mockCategories.filter((c) => provider.categories.includes(c.name))
    const photo = mockCategories.find((c) => c.name === odd.category_name)!

    const { services } = await getProviderPortfolio(provider.id)
    expect(services.filter((s) => isOutsideCategories(s, provider))).toHaveLength(1)

    const both = await setProviderCategories(provider, [...own, photo])
    expect(both.hidden).toBe(0)
    const after = (await getProvider(provider.id))!
    expect(after.categories).toEqual([...own, photo].map((c) => c.name))
    expect(services.filter((s) => isOutsideCategories(s, after))).toHaveLength(0)

    // وتغييرُه إلى «التصوير» وحده يُخفي باقاته في قسمه القديم.
    const onlyPhoto = await setProviderCategories(after, [photo])
    expect(onlyPhoto.hidden).toBe(services.length - 1)
  })

  it('ولا يُترك بلا قسم', async () => {
    const provider = (await getProvider(mockServices[0].provider_id))!
    await expect(setProviderCategories(provider, [])).rejects.toThrow('قسماً واحداً على الأقلّ')
  })
})
