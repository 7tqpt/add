// برنامجُ سطح المكتب — `src-tauri/tauri.conf.json`. طلبه صاحبُ المنصّة: «اريد
// نسخة ديس كتوب»، واختار (أ) ويندوز.
//
// كان البرنامجُ قائماً باسم «لوحة تحكم سد» وعلامتِها، **وسياستُه تمنع صورَ
// القاعدة**: `img-src` بلا `*.supabase.co`، فصورُ الخدمات والأقسام ولافتاتُ
// الإعلانات تخرج فيه مربّعاتٍ فارغة وهي تظهر في الموقع. فتُقارن السياستان هنا.
import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const conf = JSON.parse(read('src-tauri/tauri.conf.json'))

const directive = (policy: string, name: string) =>
  policy.split(';').map((d) => d.trim().split(/\s+/)).find(([n]) => n === name)?.slice(1) ?? []
const web = read('netlify.toml').match(/^\s*Content-Security-Policy = "([^"]+)"/m)?.[1] ?? ''
const desktop: string = conf.app.security.csp

describe('برنامجُ سطح المكتب', () => {
  it('**اسمُه «فرحتي» ونافذتُه «فرحتي — لوحة الإدارة»**', () => {
    expect(conf.productName).toBe('فرحتي')
    expect(conf.app.windows[0].title).toBe('فرحتي — لوحة الإدارة')
    expect(JSON.stringify(conf)).not.toContain('لوحة تحكم سد')
  })

  it('**وما يظهر من صورٍ وصوتٍ في الموقع يظهر فيه** — نطاقاتُ القاعدة نفسُها', () => {
    for (const name of ['img-src', 'media-src']) {
      const remote = directive(web, name).filter((source) => source.startsWith('https://'))
      expect(remote.length, name).toBeGreaterThan(0)
      for (const source of remote) expect(directive(desktop, name), `${name} ${source}`).toContain(source)
    }
  })

  it('ومُثبِّتُ ويندوز باسمٍ لاتينيٍّ لفرحتي', () => {
    const workflow = read('.github/workflows/desktop.yml')
    expect(workflow).toContain('out/farhati-dashboard-')
    expect(workflow).not.toContain('sdd-dashboard')
  })
})
