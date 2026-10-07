// «طلبات السحب» في اللوحة — `src/services/wallet.ts` و`supabase/wallet.sql`.
//
// المطابقةُ قرارُ القاعدة؛ وما هنا نسختُها للعرض ولوضع التجربة — فتُقاس النسختان
// معاً: لو افترقتا رأى المسؤولُ «مطابق» على ما ترفضه القاعدة، أو العكس.
import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

import { decideRefund, decideWithdrawal, normalizeAccount, type PendingRefund, type Withdrawal } from '../src/services/wallet'

const sql = readFileSync(new URL('../supabase/wallet.sql', import.meta.url), 'utf8')

describe('توحيدُ رقم الحساب', () => {
  it('**«٧٧٧ ١٢٣ ٤٥٦» و«+967777123456» و«00967777123456» حسابٌ واحد**', () => {
    for (const written of ['٧٧٧ ١٢٣ ٤٥٦', '+967777123456', '00967 777-123-456', '777123456', '۷۷۷۱۲۳۴۵۶']) {
      expect(normalizeAccount(written), written).toBe('777123456')
    }
  })

  it('**ومفتاحُ اليمن لا يُرمى إلّا أمام تسعة أرقام** — حسابُ بنكٍ يبدأ بـ967 يبقى', () => {
    expect(normalizeAccount('9671234567890')).toBe('9671234567890')
    expect(normalizeAccount('')).toBe('')
    expect(normalizeAccount(null)).toBe('')
  })

  it('**وهي نسخةُ wallet_norm في القاعدة** — الأرقامُ نفسُها والمفتاحُ نفسُه', () => {
    expect(sql).toContain("'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'")
    expect(sql).toContain("'^(00)?967(?=\\d{9}$)'")
  })
})

const withdrawal: Withdrawal = {
  id: 'wd_7', reference: 'WD-2026-0007', amount: 120000, method: 'jawali', account: '777 123 456',
  status: 'pending', note: '', created_at: '', decided_at: null, user_name: 'x', user_phone: null,
  paid_reference: null, paid_account: '777 123 456', paid_method: 'jawali', paid_booking: null, matched: true,
}
const refund: PendingRefund = {
  id: 'rfd_1', reference: 'RFD-1', amount: 170000, description: '', created_at: '', booking_id: null,
  booking_reference: 'BK-1', user_name: 'x', provider_name: 'y', paid_amount: 170000, booking_status: 'cancelled',
}

describe('قراراتُ المسؤول', () => {
  it('**رفضُ السحب بلا سببٍ لا يُرسل** — السببُ يصل العميل', async () => {
    await expect(decideWithdrawal(withdrawal, false, '   ')).rejects.toThrow(/سبب الرفض/)
  })

  it('**والاسترجاعُ لا يُعتمد بأكثر ممّا حُسب ولا بصفر**', async () => {
    await expect(decideRefund(refund, true, 170001)).rejects.toThrow(/بين ريالٍ/)
    await expect(decideRefund(refund, true, 0)).rejects.toThrow(/بين ريالٍ/)
    await expect(decideRefund(refund, false, null, '')).rejects.toThrow(/سبب الرفض/)
  })
})
