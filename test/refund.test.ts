// **ردُّ المبلغ يمرّ بالدالّة، ويُقال أين ذهب المال قبل الضغط.**
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// **١) الردُّ يستدعي `api_admin_refund_payment` ولا يكتب في الجدول.** وكان
//    يكتب: `.from('payments').update({ status: 'refunded' })`. فتصير الدفعةُ
//    مردودةً **والحجزُ لا يعلم** — `refunded_amount` صفرٌ كما كان.
//
//    وهناك يقع الضرر: `settlements.sql` يحسب مستحقَّ مقدّم الخدمة من
//    **الحجز** لا من المدفوعات — `sum(b.paid_amount - b.refunded_amount)`.
//    فمن ردَّ لعميلٍ ٥٠٠٬٠٠٠ ريالٍ من اللوحة، دفعت منصّتُه للمزوّد بعدها
//    ٤٥٠٬٠٠٠ كأنّ الردَّ لم يكن.
//
// **٢) وحالُ التسوية تُعرف قبل الفعل لا بعده.** مستحقٌّ **دُفع** لا يستردُّه
//    شيء، فيُقال للمسؤول قبل أن يضغط. ومن علم بعد وقوع الفعل لم يُنبَّه،
//    أُخبر.
//
// ── وما لا يقيسه ────────────────────────────────────────────────────────────
//
// **لا رسمَ الشريط.** لا `jsdom` في هذه الحزمة عن قصدٍ مكتوبٍ في
// `vitest.config.ts`، والمقيسُ هنا القرارُ لا شجرةُ العناصر. وصدقُ الشريط
// مقيسٌ في لقطةٍ عُرضت قبل التنفيذ.
import { beforeEach, describe, expect, it, vi } from 'vitest'

const rpc = vi.fn()

vi.mock('@/lib/supabase', () => ({
  isSupabaseConfigured: true,
  supabase: null,
  requireSupabase: () => ({
    rpc,
    // **والفخُّ على `payments` وحدَها.** فخٌّ يرمي لكلّ جدولٍ يُشعله
    // `recordAudit` — وهو يكتب في `audit_log` ويبتلع خطأه — فيمرّ الاختبارُ
    // ولم يُقَس ما ادّعى. وقد وقع ذلك في أوّل تشغيل.
    from: (table: string) => {
      if (table === 'payments') {
        throw new Error('مُسّ جدولُ المدفوعات مباشرةً — والردُّ يجب أن يمرّ بالدالّة')
      }
      const noop: Record<string, unknown> = {}
      for (const key of ['insert', 'update', 'select', 'eq', 'order', 'limit']) {
        noop[key] = () => noop
      }
      noop.then = (resolve: (v: unknown) => unknown) => resolve({ data: null, error: null })
      return noop
    },
  }),
}))

const { refundPayment, refundOutlook } = await import('@/services/finance')

const payment = {
  id: 'pay_1',
  reference: 'TRX-2026-000001',
  amount: 500000,
  user_name: 'أيمن محمد',
  provider_id: 'prv_1',
  status: 'paid',
} as never

describe('**الردُّ يمرّ بالدالّة**', () => {
  beforeEach(() => {
    rpc.mockReset()
    rpc.mockResolvedValue({ data: null, error: null })
  })

  it('يستدعي `api_admin_refund_payment` بمعرّف الدفعة', async () => {
    await refundPayment(payment)

    const call = rpc.mock.calls.find(([name]) => name === 'api_admin_refund_payment')
    expect(call, 'لم تُستدعَ دالّةُ الردّ').toBeTruthy()
    expect(call?.[1]).toMatchObject({ p_payment_id: 'pay_1' })
  })

  it('**ولا يلمس جدولَ المدفوعات** — وكان يلمسه', async () => {
    // الفخُّ في `from` أعلاه يرمي، فلو عاد المسُّ المباشرُ لَسقط هنا.
    await expect(refundPayment(payment)).resolves.toBeUndefined()
  })

  it('**والخطأُ يُرفع لا يُبتلع**', async () => {
    // ردٌّ يفشل في القاعدة ويُقال للمسؤول «تمّ» أسوأُ من ردٍّ لم يقع.
    rpc.mockResolvedValue({ data: null, error: { message: 'لا تملك صلاحية ردّ المبالغ' } })
    await expect(refundPayment(payment)).rejects.toBeTruthy()
  })
})

describe('**وحالُ التسوية تُقال قبل الضغط**', () => {
  beforeEach(() => {
    rpc.mockReset()
  })

  it('تسأل `api_refund_outlook` وتُرجع ما قالته القاعدة', async () => {
    rpc.mockResolvedValue({
      data: { refundable: true, amount: 500000, settlement: 'paid' },
      error: null,
    })

    const out = await refundOutlook(payment)

    expect(rpc).toHaveBeenCalledWith('api_refund_outlook', { p_payment_id: 'pay_1' })
    // **ويُقرأ ما وصل لا ما يُفترض.** «دُفع» و«قيد الاحتساب» مختلفتان:
    // الأولى لا تُستردّ، والثانيةُ تُعدَّل تلقائياً.
    expect(out.settlement).toBe('paid')
  })

  it('**و«قيد الاحتساب» لا تُقرأ «دُفع»**', async () => {
    rpc.mockResolvedValue({
      data: { refundable: true, amount: 500000, settlement: 'pending' },
      error: null,
    })
    expect((await refundOutlook(payment)).settlement).toBe('pending')
  })

  it('**وحجزٌ بلا تسويةٍ يُقال فيه «لا شيء»** — فلا يُخوَّف بلا سبب', async () => {
    rpc.mockResolvedValue({
      data: { refundable: true, amount: 500000, settlement: 'none' },
      error: null,
    })
    expect((await refundOutlook(payment)).settlement).toBe('none')
  })
})
