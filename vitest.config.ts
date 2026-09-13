import { defineConfig } from 'vitest/config'

/**
 * إعدادُ اختبارات لوحة التحكّم — منفصلٌ عن `vite.config.ts` عن قصد.
 *
 * **ولماذا ملفٌّ ثانٍ:** وضعُ `test` داخل `vite.config.ts` يُصرَّف بـ
 * `tsconfig.node.json` ولا يعرفه نوعُ `UserConfig` في Vite، فيسقط `tsc -b`
 * بـ«‏'test' does not exist‏» — والبناءُ هو ما يمنع الدمج. فيُفصل.
 *
 * **والنطاقُ يُحصر في `test/` صراحةً.** في المستودع حزمةُ اختباراتٍ ثانيةٌ
 * تحت `supabase/tests/*.test.mjs` تُشغَّل بـ`node --test`، وكلٌّ منها سكربتٌ
 * ينتهي بـ`process.exit`. فبلا هذا الحصر التقطها Vitest وأسقط اثنين وخمسين
 * ملفّاً في أوّل تشغيل — وهو إخفاقٌ في الإعداد يُقرأ إخفاقاً في الشيفرة.
 *
 * ولا `environment: 'jsdom'`: المقيسُ هنا منطقٌ خالصٌ لا شجرةُ عناصر. ويومَ
 * تُقاس شاشةٌ يُضاف حينها، لا قبلَه.
 */
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
  },
})
