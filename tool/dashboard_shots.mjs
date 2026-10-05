// **لقطاتُ لوحة التحكّم — في متصفّحٍ حقيقيّ، ومعها ما يُقاس ممّا رُسم.**
//
//   npm run build
//   npm i --no-save playwright-core
//   SHOTS=<مجلّد> node tool/dashboard_shots.mjs
//
// تُخدَم `dist/` ويُفتح Chromium (`/opt/pw-browsers` أو `CHROME`)، فتُصوَّر
// صفحاتُ اللوحة في وضع العرض التجريبيّ. **ويُسأل المتصفّحُ لا الملفّ:** أحُمِّل
// الخطُّ فعلاً؟ وما لونُ القائمة كما رُسم؟ وهل بقيت «Profile» أو «سد
// للبرمجيات» في الرأس؟ — ويسقط السكربتُ إن خالف شيءٌ منها.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/dashboard-shots'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4791)
const base = 'http://localhost:4791'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
let failed = 0
const check = (label, ok, extra = '') => {
  if (!ok) failed++
  console.log(`${ok ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

await page.goto(`${base}/#/login`)
await page.waitForTimeout(1200)
await page.screenshot({ path: `${out}/00-login.png` })
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1800)

const pages = [['01-home', '/'], ['02-bookings', '/bookings'], ['03-providers', '/providers'], ['05-payments', '/payments'], ['06-settings', '/settings']]
for (const [name, route] of pages) {
  await page.goto(`${base}/#${route}`)
  await page.waitForTimeout(1300)
  await page.screenshot({ path: `${out}/${name}.png` })
}
await page.goto(`${base}/#/providers`)
await page.waitForTimeout(900)
const link = await page.$('a[href*="#/providers/"]')
if (link) { await link.click(); await page.waitForTimeout(1300) }
await page.screenshot({ path: `${out}/04-provider.png` })

// ── ما يُقاس ممّا رُسم ───────────────────────────────────────────────────────
await page.goto(`${base}/#/`)
await page.waitForTimeout(1300)
const m = await page.evaluate(async () => {
  await document.fonts.ready
  const side = document.querySelector('[data-sidebar]')
  const active = side?.querySelector('a[aria-current="page"]')
  const header = document.querySelector('header')
  return {
    font: document.fonts.check('16px "IBM Plex Sans Arabic"') && [...document.fonts].some((f) => f.family.includes('IBM Plex Sans Arabic') && f.status === 'loaded'),
    sideBg: side ? getComputedStyle(side).backgroundImage : '',
    activeBg: active ? getComputedStyle(active).backgroundColor : '',
    activeText: active?.textContent?.trim() ?? '',
    headerText: header?.innerText ?? '',
    brand: side?.querySelector('[data-sidebar-head]')?.textContent ?? '',
    title: document.title,
    discs: document.querySelectorAll('[data-kpi-disc]').length,
    discBg: getComputedStyle(document.querySelector('[data-kpi-disc]') ?? document.body).backgroundColor,
  }
})
check('**الخطُّ محمَّلٌ فعلاً** — IBM Plex Sans Arabic', m.font)
check('**القائمةُ نبيذيّة**', m.sideBg.includes('rgb(92, 8, 32)') && m.sideBg.includes('rgb(123, 15, 46)'), m.sideBg.slice(0, 80))
check('والبندُ النشطُ «نظرة عامة» على ورقٍ كريميّ', m.activeText === 'نظرة عامة' && m.activeBg === 'rgb(247, 233, 236)', `${m.activeText} ${m.activeBg}`)
check('**«فرحتي» في رأس القائمة**', m.brand.includes('فرحتي') && !m.brand.includes('سد للبرمجيات'), m.brand)
check('**ولا «Profile» في الرأس**', !m.headerText.includes('Profile'), m.headerText.replace(/\s+/g, ' ').slice(0, 80))
check('والتحيّةُ في الرأس', /صباح الخير|مساء الخير/.test(m.headerText))
check('وأربعُ بطاقاتٍ بأقراصٍ ذهبيّة', m.discs === 4 && m.discBg === 'rgb(243, 231, 211)', `${m.discs} ${m.discBg}`)
check('وعنوانُ الصفحة', m.title === 'فرحتي — لوحة الإدارة', m.title)

const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
await phone.goto(`${base}/#/`)
await phone.waitForTimeout(1300)
await phone.screenshot({ path: `${out}/07-home-phone.png` })
const overflow = await phone.evaluate(() => document.documentElement.scrollWidth - innerWidth)
check('ولا تمريرَ أفقيّاً على الجوال', overflow <= 0, `${overflow}px`)

await browser.close()
server.close()
console.log(failed === 0 ? '\nكلُّ ما قيس أخضر.' : `\n${failed} سقط.`)
process.exit(failed === 0 ? 0 : 1)
