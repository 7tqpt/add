// هويّةُ «فرحتي» في لوحة التحكّم — (أ) «المخمل» من ثلاثة اتجاهاتٍ عُرضت على
// صاحب المنصّة، بعد أن قال: «اريد تغيير كامل».
//
// **ويُقاس المصدرُ حيث لا شاشةَ تُقاس:** إعدادُ Vitest هنا بلا `jsdom` (منطقٌ
// خالص)، فما يُرسم يُصوَّر بالمتصفّح الحقيقيّ في `tool/dashboard_shots.mjs`،
// وما يُكتب في الملفّات يُسأل هنا.
import { existsSync, readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

import { greeting } from '../src/components/layout/Topbar'
import { initialOf } from '../src/components/layout/UserMenu'

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')

/** قيمةُ رمزٍ في كتلة `:root` الفاتحة. */
function lightToken(name: string): string | undefined {
  const css = read('src/index.css')
  const block = css.slice(css.indexOf(":root,\n[data-theme='light'] {"), css.indexOf("[data-theme='dark'] {"))
  return block.match(new RegExp(`--${name}:\\s*([^;]+);`))?.[1]?.trim()
}

describe('ألوانُ العلامة', () => {
  it('**النبيذيُّ هو اللونُ الفاعل، والورقُ كريميّ** — لا الأزرقُ القديم', () => {
    expect(lightToken('accent')).toBe('#7b0f2e')
    expect(lightToken('page')).toBe('#fffdfa')
    expect(lightToken('gold')).toBe('#c9a46a')
  })

  it('**ولا أزرقَ باقٍ في رموز الوضعين**', () => {
    const css = read('src/index.css')
    for (const blue of ['#1d4ed8', '#60a5fa', '#2a78d6', '#f4f7fc', '#070c16']) {
      expect(css.toLowerCase(), blue).not.toContain(blue)
    }
  })

  it('**والقائمةُ نبيذيّةٌ في الوضع الداكن أيضاً**', () => {
    const css = read('src/index.css')
    const dark = css.slice(css.indexOf("[data-theme='dark'] {"))
    expect(dark).toMatch(/--side-from:\s*#[0-9a-f]{6}/)
    expect(read('src/components/layout/Sidebar.tsx')).toContain('var(--side-from), var(--side-to)')
  })
})

describe('الخطّ', () => {
  it('**IBM Plex Sans Arabic محمَّلٌ بملفّاته** — لا اسمٌ بلا ملفّ', () => {
    const css = read('src/index.css')
    for (const weight of [400, 500, 600, 700]) {
      expect(css).toContain(`/fonts/IBMPlexSansArabic-${weight}.ttf`)
      expect(existsSync(new URL(`../public/fonts/IBMPlexSansArabic-${weight}.ttf`, import.meta.url))).toBe(true)
    }
  })
})

describe('الاسمُ والعلامة', () => {
  it('**«فرحتي — لوحة الإدارة» بأيقونة التطبيق**', () => {
    const brand = read('src/components/brand/Brand.tsx')
    expect(brand).toContain('const LOGO = "/brand/farhati.png"')
    expect(brand).toMatch(/>\s*فرحتي\s*</)
    expect(brand).toContain('subtitle = "لوحة الإدارة"')
    expect(existsSync(new URL('../public/brand/farhati.png', import.meta.url))).toBe(true)
    expect(read('index.html')).toContain('<title>فرحتي — لوحة الإدارة</title>')
  })

  it('**وصانعتُها في ذيل القائمة** — كانت علامتَها', () => {
    expect(read('src/components/layout/Sidebar.tsx')).toContain('من سد للبرمجيات')
  })

  it('**ولا «Profile» إنجليزيّةً في الرأس** — قرصٌ بحرفٍ ووصفٌ عربيّ', () => {
    const menu = read('src/components/layout/UserMenu.tsx')
    expect(menu).not.toMatch(/>\s*Profile\s*</)
    expect(menu).toContain('aria-label={`حسابي — ${user.email}`}')
  })
})

describe('التحيّةُ والحرف', () => {
  it('«صباح الخير» قبل الظهر و«مساء الخير» بعده', () => {
    expect(greeting(new Date(2026, 9, 5, 9, 0))).toBe('صباح الخير')
    expect(greeting(new Date(2026, 9, 5, 11, 59))).toBe('صباح الخير')
    expect(greeting(new Date(2026, 9, 5, 12, 0))).toBe('مساء الخير')
    expect(greeting(new Date(2026, 9, 5, 23, 0))).toBe('مساء الخير')
  })

  it('**حرفُ الحساب أوّلُ حرفٍ لا أوّلُ رمز**', () => {
    expect(initialOf('owner@sdd.company')).toBe('O')
    expect(initialOf('9ayman@gmail.com')).toBe('A')
    expect(initialOf('مريم@example.com')).toBe('م')
    expect(initialOf('123@x.com')).toBe('؟')
  })
})

describe('صفحةُ الدخول — (أ) من صورتين', () => {
  const login = () => read('src/pages/Login.tsx')

  it('**ورودُ التطبيق خلف بطاقةٍ في الوسط** — لا اللوحُ الأزرقُ المائل', () => {
    expect(login()).toContain('url(/brand/roses.webp)')
    expect(login()).not.toContain('حيث تبدأ القوة')
    expect(login()).not.toContain('onPointerMove')
  })

  it('**والبطاقةُ كريميّةٌ في الوضعين** — جزيرةٌ فاتحةٌ ولو كانت اللوحةُ داكنة', () => {
    expect(login()).toMatch(/data-theme="light"\s+data-login-card/)
  })
})

describe('بقيّةُ الصفحات — (أ) من صورتين', () => {
  it('**بطاقةُ الأرقام بيضاءُ بقرصٍ ذهبيّ ورقمٍ نبيذيّ** — لا مصبوغةٌ بنوعها', () => {
    const tile = read('src/components/charts/StatTile.tsx')
    expect(tile).toContain('bg-gold-soft text-gold-ink')
    expect(tile).toContain('text-accent')
    expect(tile).not.toContain('toneStyle(')
  })

  it('**ولا صبغةَ بقيت على بطاقةٍ في الصفحات**', () => {
    for (const page of ['Payments', 'Dashboard', 'Support', 'ProviderDetail', 'UserDetail']) {
      expect(read(`src/pages/${page}.tsx`), page).not.toMatch(/tone="(azure|emerald|navy|cyan|violet)"/)
    }
  })
})
