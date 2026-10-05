// **مقترحُ بقيّة الصفحات — على الصفحات الحقيقيّة، قبل لمس `src/`.**
//
//   npm run build && SHOTS=<مجلّد> node tool/pages_proposal.mjs
//
// تُخدَم `dist/` كما هي، ثمّ يُحقن فوقها نمطُ المقترح في المتصفّح وحده، فتُصوَّر
// الصفحاتُ بعناصرها وبياناتها التجريبيّة لا برسمٍ يشبهها. (أ) و(ب) يشتركان في
// البطاقات والجداول، ويختلفان في بطاقات الأرقام وحدها.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/pages-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4792)
const base = 'http://localhost:4792'

// المشترك: بطاقاتٌ بيضاءُ بحدٍّ رمليّ كبطاقات «نظرة عامة»، ورأسُ الجدول كريميٌّ
// بحبرٍ ذهبيّ، والصفُّ عند التحويم يكتسي كريميّاً بلا إطار، والأعمدةُ أنحف.
const COMMON = `
.glass-panel{background:var(--surface)!important;-webkit-backdrop-filter:none!important;backdrop-filter:none!important;border-color:var(--border)!important;border-radius:16px!important;box-shadow:0 1px 2px rgba(42,17,25,.04),0 12px 30px -22px rgba(92,8,32,.35)!important}
thead tr,thead tr.glass-item{background:var(--surface-2)!important;border:0!important;box-shadow:none!important}
thead th{color:var(--gold-ink)!important;font-weight:600!important}
.glass-row:hover{background:color-mix(in oklab,var(--surface-2) 70%,transparent)!important;border-color:transparent!important}
ul li span.bg-surface-2{background:var(--gold-soft)!important;height:.75rem!important;border-radius:999px!important}
ul li span.bg-surface-2>span{height:.75rem!important;border-radius:999px!important;background:linear-gradient(90deg,#5c0820,#9a1b3e)!important}
`
// (أ) بطاقاتُ الأرقام كبطاقات الرئيسيّة: بيضاء، وقرصٌ ذهبيّ، والرقمُ نبيذيّ.
const TILES_A = `
.glass-tile{background:var(--surface)!important;--tile-border:var(--border)!important;border-radius:16px!important;-webkit-backdrop-filter:none!important;backdrop-filter:none!important}
.glass-tile span.size-7{background:var(--gold-soft)!important;color:var(--gold-ink)!important;width:2.75rem!important;height:2.75rem!important;border-radius:999px!important}
.glass-tile span.size-7 svg{width:20px;height:20px}
.glass-tile>p.text-2xl{color:var(--accent)!important;font-weight:700!important}
`

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1500)

async function shoot(name, route, css) {
  // التوجيهُ بالوسم لا يُعيد تحميل الوثيقة، فيبقى نمطُ اللقطة السابقة محقوناً —
  // فخرجت (ب) بأقراص (أ). فيُعاد التحميلُ قبل كلّ لقطة.
  await page.goto(`${base}/#${route}`)
  await page.reload()
  await page.waitForTimeout(1300)
  if (css) await page.addStyleTag({ content: css })
  await page.mouse.move(5, 5)
  await page.waitForTimeout(400)
  await page.screenshot({ path: `${out}/${name}.png` })
}
await shoot('now-payments', '/payments', '')
await shoot('a-payments', '/payments', COMMON + TILES_A)
await shoot('b-payments', '/payments', COMMON)
await shoot('a-bookings', '/bookings', COMMON + TILES_A)
await shoot('a-settings', '/settings', COMMON + TILES_A)
await shoot('a-providers', '/providers', COMMON + TILES_A)

await browser.close()
server.close()
