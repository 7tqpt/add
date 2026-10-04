// سياسةُ المحتوى في `netlify.toml` — رأسٌ واحدٌ يحرس اللوحةَ كلَّها.
//
// ── ولماذا يُحرَس ────────────────────────────────────────────────────────────
//
// كشف فحصٌ أمنيٌّ أنّ اللوحة بلا سياسة محتوى: نصٌّ يتسرّب إليها من بيانات
// مستخدمٍ يُنفَّذ بصلاحية المسؤول. فأُضيف الرأس. **وخطرُه أن يكسر اللوحةَ
// صامتاً**: سكربتُ الثيم في `index.html` يُسمح به ببصمته، فمن عدّله ولم
// يبدّلها وقف السكربتُ بلا خطأٍ يُرى إلّا في وحدة التحكّم.
//
// فيُحسب البصمةُ هنا من `index.html` نفسِه، لا تُنسخ.
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const toml = readFileSync(new URL('../netlify.toml', import.meta.url), 'utf8')
const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8')

const policy = toml.match(/^\s*Content-Security-Policy = "([^"]+)"/m)?.[1] ?? ''
const directive = (name: string) =>
  policy.split(';').map((d) => d.trim().split(/\s+/)).find(([n]) => n === name)?.slice(1) ?? []

describe('سياسةُ المحتوى', () => {
  it('**موجودةٌ في رؤوس اللوحة**', () => {
    expect(policy).not.toBe('')
  })

  it('**وكلُّ سكربتٍ مضمَّنٍ في index.html مسموحٌ ببصمته**', () => {
    const inline = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])
    expect(inline.length).toBeGreaterThan(0)
    for (const body of inline) {
      const hash = `'sha256-${createHash('sha256').update(body).digest('base64')}'`
      expect(directive('script-src'), 'بُدِّل سكربتُ الثيم ولم تُبدَّل بصمتُه في netlify.toml').toContain(hash)
    }
  })

  it('**ولا يُنفَّذ نصٌّ مضمَّنٌ غيرُها** — لا unsafe-inline ولا unsafe-eval', () => {
    expect(directive('script-src')).not.toContain("'unsafe-inline'")
    expect(directive('script-src')).not.toContain("'unsafe-eval'")
    expect(directive('object-src')).toEqual(["'none'"])
  })

  it('**وتصل Supabase** — الطلباتُ والقناةُ الحيّةُ والصورُ والمقاطع', () => {
    expect(directive('connect-src')).toEqual(expect.arrayContaining(['https://*.supabase.co', 'wss://*.supabase.co']))
    expect(directive('img-src')).toEqual(expect.arrayContaining(['https://*.supabase.co', 'blob:', 'data:']))
    expect(directive('media-src')).toContain('https://*.supabase.co')
  })

  it('**ولا تُؤطَّر في صفحة غيرها**', () => {
    expect(directive('frame-ancestors')).toEqual(["'none'"])
  })
})
