// **مقترحُ «تغيير القسم» في صفحة مقدّم الخدمة، وخدماتٍ خارج قسمه مخفيّة — قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/provider_categories_proposal.mjs
//
// اختار صاحبُ المنصّة: (أ) الإدارةُ تغيّر قسمَ المزوّد من صفحته وتضيف له قسماً
// ثانياً، و(ب) خدماتُه في قسمٍ غير أقسامه تُخفى عن العملاء حتى تُراجَع. فتُفتح
// صفحةُ مزوّدٍ حقيقيّةٌ في وضع العرض، ويُرسم فوقها — **مرسوماً**: زرُّ «تغيير
// القسم» (نسخةُ زرٍّ حقيقيٍّ منها)، وعلامةُ «خارج قسمه» على خدمة، ثمّ النافذة.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/provider-categories-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4798)
const base = 'http://localhost:4798'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1300)



await page.goto(`${base}/#/providers`)
await page.waitForTimeout(1500)
// مزوّدٌ موثَّقٌ له خدمات — تُجرَّب الصفوفُ حتى يوجد جدولُ خدمات.
const hrefs = await page.locator('tbody a[href*="#/providers/"]').evaluateAll((as) => as.map((a) => a.getAttribute('href')))
for (const href of hrefs) {
  await page.goto(`${base}/${href}`)
  await page.waitForTimeout(1300)
  const rows = await page.evaluate(() => {
    const t = [...document.querySelectorAll('h2, h3, div')].find((el) => el.childElementCount === 0 && el.textContent.trim() === 'الخدمات المعروضة')
    return t ? (t.closest('.overflow-hidden')?.querySelectorAll('tbody tr').length ?? 0) : 0
  })
  if (rows >= 2) break
}

const mark = () => {
  const header = document.querySelector('main h2, main h3')?.closest('div')?.parentElement
  const subtitle = [...document.querySelectorAll('p')].find((p) => p.textContent.includes(' · '))
  const actions = document.querySelector('main button')?.parentElement
  const any = [...document.querySelectorAll('main button')].find((b) => /ملفّه|رفض|إيقاف|تعليق|قبول|توثيق/.test(b.textContent)) ?? document.querySelector('main button')
  if (actions && any) {
    const b = any.cloneNode(true)
    b.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h7v7H3zM14 6h7v7h-7zM3 17h7M14 17h7"/></svg>تغيير القسم'
    b.className = any.className.replace(/bg-\S+|text-white/g, '')
    b.style.cssText = 'border:1px solid var(--border);color:var(--accent);font-weight:600;background:var(--surface)'
    b.disabled = false
    actions.prepend(b)
  }
  // خدمةٌ في قسمٍ غير قسمه: سطرُ قسمها تحت اسمها، وشارةٌ حمراء.
  const services = [...document.querySelectorAll('h2, h3, div')].find((el) => el.childElementCount === 0 && el.textContent.trim() === 'الخدمات المعروضة')
  const card = services?.closest('.overflow-hidden')
  const rows = card ? [...card.querySelectorAll('tbody tr')] : []
  const victim = rows[1] ?? rows[0]
  if (victim) {
    const first = victim.querySelector('td')
    const line = document.createElement('span')
    line.style.cssText = 'display:block;font-size:11px;color:var(--critical);margin-top:2px'
    line.textContent = 'في «التصوير والإضاءة» — ليس من أقسامه'
    first.insertBefore(line, first.childNodes[1] ?? null)
    const last = victim.querySelector('td:last-child')
    last.innerHTML = '<span style="display:inline-flex;align-items:center;gap:4px;border-radius:999px;padding:2px 8px;font-size:12px;border:1px solid color-mix(in oklab,var(--critical) 45%,transparent);background:color-mix(in oklab,var(--critical) 12%,transparent);color:var(--critical);white-space:nowrap">مخفيّة عن العملاء</span>'
    const note = document.createElement('div')
    note.style.cssText = 'margin:0 16px 10px;padding:8px 12px;border-radius:10px;font-size:12px;line-height:1.8;background:color-mix(in oklab,var(--critical) 8%,transparent);color:var(--ink)'
    note.innerHTML = '<b style="color:var(--critical)">خدمةٌ واحدة خارج أقسامه</b> — مخفيّةٌ عن العملاء حتى تضيف قسمَها له من «تغيير القسم»، أو يعدّلها هو إلى قسمه.'
    const table = card.querySelector('.overflow-x-auto') ?? card.querySelector('table')
    table?.parentElement.insertBefore(note, table)
    victim.scrollIntoView({ block: 'center' })
  }
  window.scrollTo(0, 0)
}
await page.evaluate(`(${mark})()`)
// الصفحةُ تُمرَّر في حاويتها لا في النافذة: يُطلب رأسُها بعينه.
await page.evaluate(() => [...document.querySelectorAll('a')].find((a) => a.textContent.includes('كل مقدّمي الخدمة'))?.scrollIntoView({ block: 'start' }))
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/cat-1-page.png` })

// الخدماتُ نفسُها: مرّرها إلى الوسط.
await page.evaluate(() => {
  const el = [...document.querySelectorAll('span')].find((s) => s.textContent === 'مخفيّة عن العملاء')
  el?.scrollIntoView({ block: 'center' })
})
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/cat-2-services.png` })

const dialog = () => {
  window.scrollTo(0, 0)
  const cats = ['القاعات والخيام', 'الطبخ والضيافة', 'التصوير والإضاءة', 'الديكور والكوشة', 'الفنانين والفرق', 'التجميل والعرائس']
  const on = new Set(['القاعات والخيام', 'التصوير والإضاءة'])
  const veil = document.createElement('div')
  veil.style.cssText = 'position:fixed;inset:0;background:rgba(40,10,20,.45);display:grid;place-items:center;z-index:99'
  veil.innerHTML = `
  <div style="width:460px;background:var(--surface,#fff);border:1px solid var(--border);border-radius:18px;padding:22px;box-shadow:0 20px 50px rgba(0,0,0,.25);font-size:14px;color:var(--ink)">
    <div style="font-size:17px;font-weight:700;margin-bottom:6px">أقسام مقدّم الخدمة</div>
    <div style="font-size:12px;color:var(--text-muted);line-height:1.8;margin-bottom:14px">يضيف خدماتٍ في هذه الأقسام وحدها، ويراه العميلُ فيها. وما كان من خدماته في غيرها يُخفى.</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px">
      ${cats.map((c) => `<label style="display:flex;align-items:center;gap:8px;padding:9px 10px;border-radius:12px;border:1px solid ${on.has(c) ? 'var(--accent)' : 'var(--border)'};${on.has(c) ? 'background:color-mix(in oklab,var(--accent) 8%,transparent);font-weight:600' : ''}"><span style="width:16px;height:16px;border-radius:4px;display:grid;place-items:center;border:1.5px solid ${on.has(c) ? 'var(--accent)' : 'var(--border)'};${on.has(c) ? 'background:var(--accent);color:#fff;font-size:11px' : ''}">${on.has(c) ? '✓' : ''}</span>${c}</label>`).join('')}
    </div>
    <div style="background:var(--gold-soft,#f7efe0);border-radius:12px;padding:10px 12px;font-size:13px;line-height:1.8;margin-bottom:18px">
      بإضافة «التصوير والإضاءة» تعود خدمتُه المخفيّةُ إلى العملاء.
    </div>
    <div style="display:flex;gap:8px">
      <span style="padding:9px 22px;border-radius:12px;background:var(--accent);color:#fff;font-weight:600">احفظ</span>
      <span style="padding:9px 18px;border-radius:12px;border:1px solid var(--border)">إلغاء</span>
    </div>
  </div>`
  document.body.append(veil)
}
await page.evaluate(`(${dialog})()`)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/cat-3-dialog.png` })

await browser.close()
server.close()
