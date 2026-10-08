// **مقترحُ «زرّ تفريغ» الحملات — للمالك وحده — على صفحة اللوحة الحقيقيّة، قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/promotions_clear_proposal.mjs
//
// قال صاحبُ المنصّة: «اريد زر تفريغ خاص للمدير». فتُفتح «الاشتراكات والإعلانات»
// في وضع العرض، ويُرسم فوق جدول الحملات زرُّ «تفريغ المنتهية» — **مرسوماً**
// بنسخ زرٍّ حقيقيٍّ من الصفحة — ثمّ نافذةُ التأكيد **مرسومةً** بألوان اللوحة.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/promotions-clear-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4797)
const base = 'http://localhost:4797'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1300)
await page.goto(`${base}/#/promotions`)
await page.waitForTimeout(1600)


// الزرُّ: نسخةٌ من «إلغاء» الحقيقيّ في الجدول، بنصٍّ آخر، فوق الجدول يسارَ العنوان.
const button = () => {
  const ended = [...document.querySelectorAll('tbody tr')].filter((r) => /منتهية|ملغاة|انتهت مدّتها/.test(r.innerText)).length
  const heading = [...document.querySelectorAll('h2, h3, p, div')].find((el) => el.childElementCount === 0 && el.textContent.trim() === 'الحملات الترويجية')
  const block = heading?.parentElement
  const cancel = document.querySelector('tbody button')
  if (!block || !cancel) return
  const b = cancel.cloneNode(true)
  b.innerHTML = `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6"/></svg>تفريغ المنتهية (${ended})`
  b.style.cssText += ';color:var(--critical);border:1px solid color-mix(in oklab,var(--critical) 35%,transparent);font-weight:600'
  b.disabled = false
  const row = document.createElement('div')
  row.style.cssText = 'display:flex;align-items:flex-end;justify-content:space-between;gap:12px'
  block.parentElement.insertBefore(row, block)
  row.append(block, b)
  const tag = document.createElement('span')
  tag.textContent = 'للمالك وحده'
  tag.style.cssText = 'font-size:11px;color:var(--text-muted);margin-inline-start:8px'
  b.after(tag)
  row.scrollIntoView({ block: 'start' })
  window.scrollBy(0, -12)
}
await page.evaluate(`(${button})()`)
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/clear-1-button.png` })

const dialog = () => {
  const ended = [...document.querySelectorAll('tbody tr')].filter((r) => /منتهية|ملغاة|انتهت مدّتها/.test(r.innerText)).length
  const veil = document.createElement('div')
  veil.style.cssText = 'position:fixed;inset:0;background:rgba(40,10,20,.45);display:grid;place-items:center;z-index:99'
  veil.innerHTML = `
  <div style="width:460px;background:var(--surface,#fff);border:1px solid var(--hairline);border-radius:18px;padding:22px;box-shadow:0 20px 50px rgba(0,0,0,.25);font-size:14px;color:var(--ink)">
    <div style="font-size:17px;font-weight:700;margin-bottom:10px">تفريغ الحملات المنتهية؟</div>
    <div style="line-height:1.9;margin-bottom:14px">تُحذف <b>${ended} حملات</b> منتهية وملغاة من القائمة، وصورُ لافتاتها من التخزين — <b>نهائيّاً</b>.</div>
    <div style="background:var(--gold-soft,#f7efe0);border-radius:12px;padding:10px 12px;font-size:13px;line-height:1.9;margin-bottom:18px">
      • الجاريةُ والمجدولةُ لا تُمسّ.<br>
      • والمبالغُ المدفوعة تبقى في «عمليات الدفع» وتقارير الدخل.
    </div>
    <div style="display:flex;gap:8px">
      <span style="padding:9px 22px;border-radius:12px;background:var(--critical);color:#fff;font-weight:600">فرّغ ${ended}</span>
      <span style="padding:9px 18px;border-radius:12px;border:1px solid var(--hairline)">إلغاء</span>
    </div>
  </div>`
  document.body.append(veil)
}
await page.evaluate(`(${dialog})()`)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/clear-2-confirm.png` })

await browser.close()
server.close()
