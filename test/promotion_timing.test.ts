// حالُ الحملة من تاريخها — اختار صاحبُ المنصّة (ب): «تصحيح الحالة والتنبيه».
//
// انتهت لافتاتُه في منتصف الليل فغابت من التطبيق، واللوحةُ بقيت تقول «جارية»
// لأنّ عمودَ الحالة لا يتبدّل إلّا بالدورة اليوميّة. فيُقاس أنّ اللوحة تقول
// ما يراه العميل.
import { describe, expect, it } from 'vitest'

import { listPromotions, promotionTiming } from '../src/services/growth'

const NOW = new Date('2026-10-07T21:23:00Z')
const at = (hours: number) => new Date(NOW.getTime() + hours * 3_600_000).toISOString()

describe('حالُ الحملة من تاريخها', () => {
  it('**«جارية» في العمود وقد انقضت: تُقال «انتهت مدّتها» ولماذا لا تظهر**', () => {
    // ما رآه صاحبُ المنصّة بعينه: نهايتُها 20:59:59 والآن 21:23.
    const t = promotionTiming({ status: 'active', ends_at: '2026-10-07T20:59:59Z' }, NOW)
    expect(t.status).toBe('ended')
    expect(t.label).toBe('انتهت مدّتها')
    expect(t.note).toEqual({ text: 'انتهت قبل دقائق — لا تظهر في التطبيق', tone: 'critical' })
  })

  it('وتُعدّ المدّةُ منذ انتهائها', () => {
    expect(promotionTiming({ status: 'active', ends_at: at(-1) }, NOW).note?.text).toBe(
      'انتهت قبل ساعة — لا تظهر في التطبيق',
    )
    // ساعةٌ ونصف «قبل ساعة» لا «قبل ساعتين»: ما مضى يُعدّ بما اكتمل.
    expect(promotionTiming({ status: 'active', ends_at: at(-1.5) }, NOW).note?.text).toBe(
      'انتهت قبل ساعة — لا تظهر في التطبيق',
    )
    expect(promotionTiming({ status: 'active', ends_at: at(-3 * 24 - 2) }, NOW).note?.text).toBe(
      'انتهت قبل 3 أيام — لا تظهر في التطبيق',
    )
    // ومجدولةٌ فات موعدُ نهايتها لم تُعرض يوماً ولن تُعرض.
    expect(promotionTiming({ status: 'scheduled', ends_at: at(-5) }, NOW).status).toBe('ended')
  })

  it('**وما ينتهي خلال ثلاثة أيّامٍ يُنبَّه عليه قبل أن يغيب**', () => {
    expect(promotionTiming({ status: 'active', ends_at: at(40) }, NOW).note).toEqual({
      text: 'تنتهي خلال يومين',
      tone: 'warning',
    })
    expect(promotionTiming({ status: 'active', ends_at: at(5) }, NOW).note?.text).toBe('تنتهي خلال 5 ساعات')
    expect(promotionTiming({ status: 'active', ends_at: at(72) }, NOW).note?.text).toBe('تنتهي خلال 3 أيام')
    expect(promotionTiming({ status: 'active', ends_at: at(73) }, NOW).note).toBeNull()
  })

  it('والجاريةُ البعيدةُ والمنتهيةُ والملغاةُ تبقى كما في عمودها', () => {
    expect(promotionTiming({ status: 'active', ends_at: at(24 * 15) }, NOW)).toEqual({
      status: 'active',
      label: 'جارية',
      note: null,
    })
    expect(promotionTiming({ status: 'ended', ends_at: at(-48) }, NOW)).toEqual({
      status: 'ended',
      label: 'منتهية',
      note: null,
    })
    expect(promotionTiming({ status: 'cancelled', ends_at: at(24) }, NOW).label).toBe('ملغاة')
  })

  it('**ووضعُ العرض فيه الحالتان لتُريا**', async () => {
    const { rows } = await listPromotions({ search: '', status: 'all', kind: 'all', page: 0, pageSize: 50 })
    const timings = rows.map((p) => promotionTiming(p))
    expect(timings.some((t) => t.label === 'انتهت مدّتها')).toBe(true)
    expect(timings.some((t) => t.note?.tone === 'warning')).toBe(true)
  })
})
