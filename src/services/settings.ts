import { requireSupabase } from '@/lib/supabase'
import type { AppSettings } from '@/lib/types'
import { mockSettings } from '@/data/mock'
import { delay, isSupabaseConfigured } from './base'
import { recordAudit } from './audit'

const demoSettings: AppSettings = { ...mockSettings }

/**
 * The values as last read from the source of truth, in either mode. Kept so the
 * audit entry can name which fields actually moved rather than logging the whole
 * form on every save.
 */
let lastLoaded: AppSettings | null = null

/**
 * أعمدة أرقام التحويل — أحدثُ من اللوحة نفسها.
 *
 * **ولماذا تُعدّ:** القاعدة والواجهة يُحدَّثان بيدين في وقتين. فلوحةٌ ترسل
 * `pay_jawali` إلى قاعدةٍ لم يُطبَّق عليها `payments_app.sql` لا يفشل فيها
 * حقلُ الدفع وحده — يفشل الحفظ كلّه بـ 42703، فلا يُحفظ وضعُ الصيانة ولا
 * العمولة. فتُقرأ الأعمدة الموجودة فعلاً، ويُبنى عليها الإرسال.
 */
const PAY_FIELDS = [
  'pay_jawali',
  'pay_kuraimi',
  'pay_bank',
  'pay_note',
  'promo_featured_daily',
] as const

let payFieldsPresent = true

/** هل تحمل القاعدة أعمدة أرقام التحويل؟ يصحّ بعد `getSettings`. */
export function hasPaymentFields(): boolean {
  return payFieldsPresent
}

/** يملأ ما لم تُنشئه القاعدة بعدُ بفراغٍ، ليبقى الحقل مضبوطاً لا معلّقاً. */
function normalise(row: Record<string, unknown>): AppSettings {
  payFieldsPresent = PAY_FIELDS.every((key) => key in row)
  const filled: Record<string, unknown> = { ...row }
  // نصٌّ للأرقام وصفرٌ للسعر: حقلٌ مضبوطٌ بـ`undefined` يصير غير مضبوط، فيصرخ
  // React ويفقد الحقل ما يُكتب فيه.
  for (const key of PAY_FIELDS) filled[key] ??= key === 'promo_featured_daily' ? 0 : ''
  return filled as unknown as AppSettings
}

export async function getSettings(): Promise<AppSettings> {
  if (!isSupabaseConfigured) {
    const settings = { ...demoSettings }
    lastLoaded = settings
    payFieldsPresent = true
    return delay(settings)
  }

  const { data, error } = await requireSupabase()
    .from('app_settings')
    .select('*')
    .eq('id', 1)
    .single()
  if (error) throw error
  const settings = normalise(data as Record<string, unknown>)
  lastLoaded = settings
  return settings
}

export async function saveSettings(settings: AppSettings): Promise<void> {
  const previous = lastLoaded
  const changed = previous
    ? (Object.keys(settings) as (keyof AppSettings)[]).filter(
        (key) => settings[key] !== previous[key],
      )
    : []

  if (!isSupabaseConfigured) {
    Object.assign(demoSettings, settings)
    await delay(null, 420)
  } else {
    const payload: Record<string, unknown> = {
      ...settings,
      updated_at: new Date().toISOString(),
    }
    if (!payFieldsPresent) for (const key of PAY_FIELDS) delete payload[key]
    const { error } = await requireSupabase().from('app_settings').update(payload).eq('id', 1)
    if (error) throw error
  }

  lastLoaded = { ...settings }

  await recordAudit({
    action: 'settings.update',
    entity: 'settings',
    entityId: '1',
    entityLabel: 'إعدادات التطبيق',
    details: { maintenance_mode: settings.maintenance_mode, changed },
  })
}
