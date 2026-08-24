import { isSupabaseConfigured } from '@/lib/supabase'

export { isSupabaseConfigured }

/** Mimics network latency so loading states are exercised in demo mode. */
export function delay<T>(value: T, ms = 260): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms))
}

/** Trims an ISO day range to the last `days` entries of an ascending series. */
export function lastDays<T>(series: T[], days: number): T[] {
  return series.slice(Math.max(0, series.length - days))
}

/**
 * Fractional change between the selected window and the window of equal length
 * immediately before it. Returns 0 when there is no prior window to compare to,
 * which is honest: "no change measured" rather than a fabricated +100%.
 */
export function periodChange(values: number[], days: number): number {
  const current = values.slice(Math.max(0, values.length - days))
  const previous = values.slice(Math.max(0, values.length - days * 2), Math.max(0, values.length - days))
  if (previous.length === 0) return 0
  const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0)
  const before = sum(previous)
  if (before === 0) return 0
  return (sum(current) - before) / before
}

export const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0)

/**
 * نصُّ الخطأ كما جاء من القاعدة، لا رسالةٌ عامّة مكانه.
 *
 * **ولماذا هذا موجود:** `PostgrestError` كائنٌ عاديّ لا يرث `Error`، فكل شاشةٍ
 * تكتب `cause instanceof Error ? cause.message : 'تعذّر…'` ترمي النصَّ الحقيقي
 * وتعرض جملةً لا تدلّ على شيء. وقد وقع: «تعذّر إرسال الإشعار» بينما القاعدة
 * كانت تقول بالحرف أيَّ صلاحيةٍ تنقص — فبحثنا نصف ساعة عمّا كان مكتوباً.
 *
 * وما ترميه القاعدة عربيٌّ مكتوبٌ للمستخدم أصلاً (`raise exception 'لا صلاحية…'`)،
 * فعرضُه أنفعُ من إخفائه.
 */
export function errorText(cause: unknown, fallback: string): string {
  if (typeof cause === 'string' && cause.trim()) return cause
  if (cause && typeof cause === 'object') {
    const message = (cause as { message?: unknown }).message
    if (typeof message === 'string' && message.trim()) return message
  }
  return fallback
}

/** The ISO day `days` back from today, used to bound Supabase queries. */
export function isoDaysAgo(days: number): string {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  d.setDate(d.getDate() - days)
  return d.toISOString().slice(0, 10)
}
