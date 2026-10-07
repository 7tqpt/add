// **مقترحُ «رقم الفاتورة جنب رقم الحجز» — على صفحات اللوحة الحقيقيّة، قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/invoice_proposal.mjs
//
// قال صاحبُ المنصّة: «اريد رقم فاتورة للكل حجز عشن اقدر اعرف جنب رقم الحجز».
// الفواتيرُ موجودةٌ في القاعدة (تصدر عند تأكيد المزوّد) واللوحةُ لا تعرضها. فتُفتح
// «الحجوزات» وصفحةُ حجزٍ في وضع العرض، ويُضاف تحت كلّ رقم حجزٍ رقمُ فاتورته
// مرسوماً — **(أ)**: رقمٌ يتبع رقمَ الحجز (INV-2026-000067 لـBK-2026-000067)،
// وما لم يُؤكَّد بعدُ: «تصدر عند التأكيد».
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/invoice-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4795)
const base = 'http://localhost:4795'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1300)

// رقمُ الفاتورة من رقم الحجز، والحالُ من شارة الصفّ: ما لم يُؤكَّد لا فاتورةَ له.
const mark = () => {
  const confirmed = (text) => /مؤكد|منفّذ/.test(text)
  for (const link of document.querySelectorAll('tbody a[href*="#/bookings/"]')) {
    const ref = link.textContent.trim()
    const row = link.closest('tr')
    const ok = confirmed(row?.innerText ?? '')
    const span = document.createElement('span')
    span.setAttribute('dir', 'ltr')
    span.className = 'mt-0.5 block text-start text-[11px] whitespace-nowrap'
    span.style.color = ok ? 'var(--gold-ink)' : 'var(--text-muted)'
    span.textContent = ok ? ref.replace('BK-', 'INV-') : 'الفاتورة: تصدر عند التأكيد'
    if (!ok) span.setAttribute('dir', 'rtl')
    link.after(span)
  }
}

await page.goto(`${base}/#/bookings`)
await page.waitForTimeout(1500)
await page.evaluate(`(${mark})()`)
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/invoice-list.png` })

// صفحةُ حجزٍ مؤكَّد: رقمُ الفاتورة تحت رقم الحجز في رأس البطاقة، وزرُّ عرضها.
const confirmedLink = await page.evaluate(() => {
  for (const a of document.querySelectorAll('tbody a[href*="#/bookings/"]')) {
    if (/مؤكد/.test(a.closest('tr')?.innerText ?? '')) return a.getAttribute('href')
  }
  return null
})
await page.goto(`${base}/${confirmedLink}`)
await page.waitForTimeout(1500)
await page.evaluate(() => {
  const title = document.querySelector('h2 span[dir="ltr"]')
  const ref = title.textContent.trim()
  const line = document.createElement('span')
  line.className = 'mt-1 flex items-center gap-2 text-xs font-medium'
  line.style.color = 'var(--gold-ink)'
  line.innerHTML = `<span>رقم الفاتورة</span><span dir="ltr" class="tnum">${ref.replace('BK-', 'INV-')}</span><span class="rounded-full border border-hairline px-2 py-0.5 text-[11px]" style="color:var(--good)">مدفوعة</span>`
  title.after(line)
})
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/invoice-detail.png` })

await browser.close()
server.close()
