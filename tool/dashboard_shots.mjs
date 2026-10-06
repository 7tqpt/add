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

// ── صفحةُ الدخول — (أ): البطاقةُ كريميّةٌ على الورود، **في الوضعين** ─────────
async function measureLogin(p) {
  return p.evaluate(async () => {
    await document.fonts.ready
    const root = document.querySelector('[data-login]')
    const card = document.querySelector('[data-login-card]')
    const field = card?.querySelector('input[type=email]')
    const bg = root ? getComputedStyle(root).backgroundImage : ''
    const img = new Image()
    img.src = '/brand/roses.webp'
    await img.decode().catch(() => {})
    return {
      roses: bg.includes('/brand/roses.webp') && img.naturalWidth > 0,
      card: card ? getComputedStyle(card).backgroundColor : '',
      title: card?.querySelector('h1')?.textContent ?? '',
      fieldBg: field ? getComputedStyle(field).backgroundColor : '',
      fieldH: field?.getBoundingClientRect().height ?? 0,
      old: document.body.innerText.includes('حيث تبدأ القوة'),
      overflow: document.documentElement.scrollWidth - innerWidth,
    }
  })
}
for (const theme of ['light', 'dark']) {
  await page.goto(`${base}/#/login`)
  await page.evaluate((t) => localStorage.setItem('theme', t), theme)
  await page.reload()
  await page.waitForTimeout(1200)
  await page.screenshot({ path: `${out}/00-login-${theme}.png` })
  const l = await measureLogin(page)
  check(`**الدخول (${theme}): الورودُ خلفها محمَّلة**`, l.roses)
  check(`والبطاقةُ كريميّة (${theme})`, l.card === 'rgb(255, 253, 250)', l.card)
  check(`و«فرحتي» عنوانُها، ولا اللوحُ القديم (${theme})`, l.title === 'فرحتي' && !l.old, l.title)
  check(`والحقلُ أبيضُ بارتفاع ٤٨ (${theme})`, l.fieldBg === 'rgb(255, 255, 255)' && l.fieldH === 48, `${l.fieldBg} ${l.fieldH}`)
}
await page.evaluate(() => localStorage.removeItem('theme'))
const loginPhone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
await loginPhone.goto(`${base}/#/login`)
await loginPhone.waitForTimeout(1200)
await loginPhone.screenshot({ path: `${out}/00-login-phone.png` })
const lp = await measureLogin(loginPhone)
check('والدخولُ على الجوال بلا تمريرٍ أفقيّ', lp.overflow <= 0, `${lp.overflow}px`)
await loginPhone.close()

await page.goto(`${base}/#/login`)
await page.reload()
await page.waitForTimeout(1200)
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

// ── بقيّةُ الصفحات — (أ): بطاقاتٌ بيضاء، وأقراصٌ ذهبيّة، ورؤوسُ جداولَ ذهبيّة ──
await page.goto(`${base}/#/payments`)
await page.waitForTimeout(1500)
const pay = await page.evaluate(() => {
  const css = (el, prop) => (el ? getComputedStyle(el)[prop] : '')
  const stats = [...document.querySelectorAll('[data-stat]')]
  const panel = document.querySelector('.glass-panel')
  return {
    stats: stats.length,
    statBg: [...new Set(stats.map((el) => css(el, 'backgroundColor')))],
    discBg: [...new Set(stats.map((el) => css(el.querySelector('[data-stat-disc]'), 'backgroundColor')))],
    valueInk: [...new Set(stats.map((el) => css(el.querySelector('p[title], p.text-2xl'), 'color')))],
    th: [...new Set([...document.querySelectorAll('thead th')].map((el) => css(el, 'color')))],
    panelBg: css(panel, 'backgroundColor'),
    panelBorder: css(panel, 'borderTopColor'),
    track: css(document.querySelector('[data-bar-track]'), 'backgroundColor'),
  }
})
check('**المدفوعات: أربعُ بطاقاتِ أرقامٍ بيضاء**', pay.stats === 4 && pay.statBg.join() === 'rgb(255, 255, 255)', `${pay.stats} ${pay.statBg}`)
check('**بأقراصٍ ذهبيّة**', pay.discBg.join() === 'rgb(243, 231, 211)', pay.discBg.join(' | '))
check('**والرقمُ نبيذيّ**', pay.valueInk.join() === 'rgb(123, 15, 46)', pay.valueInk.join(' | '))
check('**ورأسُ الجدول بحبرٍ ذهبيّ**', pay.th.length > 0 && pay.th.join() === 'rgb(138, 95, 20)', pay.th.join(' | '))
check('**والبطاقةُ بيضاءُ بحدٍّ رمليّ لا ورديّ**', pay.panelBg === 'rgb(255, 255, 255)' && pay.panelBorder === 'rgb(235, 218, 205)', `${pay.panelBg} ${pay.panelBorder}`)
check('ومجرى الأعمدة ذهبيٌّ فاتح', pay.track === 'rgb(243, 231, 211)', pay.track)

const phone = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
await phone.goto(`${base}/#/`)
await phone.waitForTimeout(1300)
await phone.screenshot({ path: `${out}/07-home-phone.png` })
const overflow = await phone.evaluate(() => document.documentElement.scrollWidth - innerWidth)
check('ولا تمريرَ أفقيّاً على الجوال', overflow <= 0, `${overflow}px`)

// ── البرنامج: وصلاتُ `_blank` تصل متصفّحَ النظام ────────────────────────────
// يُحقن `__TAURI_INTERNALS__` كما يحقنه Tauri قبل أيّ سطرٍ من شيفرتنا، فتعمل
// اللوحةُ كأنّها في البرنامج. **ويُقاس ما وصل Tauri لا ما رُسم:** كلُّ نداءٍ
// يُسجَّل، فيُسأل: أطُلب `plugin:opener|open_url` بالرابط نفسه؟
const desk = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await desk.addInitScript(() => {
  window.__calls = []
  window.__TAURI_INTERNALS__ = {
    metadata: { currentWindow: { label: 'main' }, currentWebview: { label: 'main', windowLabel: 'main' } },
    transformCallback: () => 0,
    invoke: (cmd, args) => { window.__calls.push([cmd, args]); return Promise.resolve(null) },
  }
})
await desk.goto(`${base}/#/login`)
await desk.waitForTimeout(900)
await desk.fill('input[type=email]', 'owner@sdd.company')
await desk.fill('input[type=password]', 'demo-password')
await desk.click('button[type=submit]')
await desk.waitForTimeout(1200)
await desk.goto(`${base}/#/versions`)
await desk.waitForTimeout(1300)
const windowsBefore = desk.context().pages().length
const external = desk.locator('a[target="_blank"][href^="https://"]').first()
const href = await external.getAttribute('href').catch(() => null)
if (href) await external.click()
await desk.waitForTimeout(600)
const opened = await desk.evaluate(() => window.__calls.filter(([cmd]) => cmd === 'plugin:opener|open_url').map(([, a]) => a.url))
check('**البرنامج: رابطُ «الإصدارات» يُسلَّم إلى متصفّح النظام**', !!href && opened.length === 1 && opened[0] === href, `${href} → ${JSON.stringify(opened)}`)
check('ولا نافذةَ ثانيةً داخل البرنامج', desk.context().pages().length === windowsBefore)
await desk.close()

await browser.close()
server.close()
console.log(failed === 0 ? '\nكلُّ ما قيس أخضر.' : `\n${failed} سقط.`)
process.exit(failed === 0 ? 0 : 1)
