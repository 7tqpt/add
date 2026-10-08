// **مقترحُ (ب): الموافقةُ على خدمةٍ في قسمٍ جديدٍ تضيف قسمَها لأقسام صاحبها — قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/approve_adds_category_proposal.mjs
//
// سأل صاحبُ المنصّة: «ليش عن المزود جالس يظهر الملبوسات وفي الاصل تم تغيير القسم
// الي طباعة»، واختار (ب). فتُفتح «مقدّمو الخدمة» الحقيقيّةُ في وضع العرض — وبطاقةُ
// «خدماتٌ بانتظار موافقتك» فيها حقيقيّة — ويُرسم عليها **مرسوماً**: سطرٌ تحت
// «موافقة» يقول ما تفعله، ويُرفع رابطُ «أضف القسم لأقسامه» لأنّ الموافقةَ صارت تفعله.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/approve-adds-category-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4800)
const base = 'http://localhost:4800'

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
await page.evaluate(() => {
  for (const tr of document.querySelectorAll('[data-pending-services] tbody tr')) {
    const cat = tr.querySelector('td:nth-child(3)')?.textContent?.trim() ?? ''
    const owner = tr.querySelector('td:nth-child(2)')?.textContent?.trim() ?? ''
    const buttons = tr.querySelector('[data-review-buttons]')
    if (buttons) {
      const hint = document.createElement('span')
      hint.style.cssText = 'display:block;margin-top:4px;font-size:11px;color:var(--text-muted);white-space:normal;max-width:220px;line-height:1.6'
      hint.textContent = `الموافقةُ تضيف «${cat}» لأقسام ${owner}`
      buttons.after(hint)
    }
    const link = tr.querySelector('[data-add-category]')?.closest('td')
    if (link) link.remove()
  }
  const lastTh = document.querySelector('[data-pending-services] thead th:last-child')
  lastTh?.remove()
  document.querySelector('[data-pending-services]')?.scrollIntoView({ block: 'start' })
})
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/adds-1-card.png` })

// وبعد الموافقة: رسالةٌ تقول ما وقع (مرسومة).
await page.evaluate(() => {
  const toast = document.createElement('div')
  toast.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:var(--ink,#2a1018);color:#fff;padding:12px 18px;border-radius:12px;font-size:13px;z-index:99;box-shadow:0 10px 30px rgba(0,0,0,.25)'
  toast.textContent = 'ظهرت الخدمة للعملاء — وأُضيف «التصوير والإضاءة» لأقسام قاعة الأصالة.'
  document.body.append(toast)
})
await page.waitForTimeout(200)
await page.screenshot({ path: `${out}/adds-2-toast.png` })

await browser.close()
server.close()
