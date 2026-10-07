// **مقترحُ «حالةُ اللافتة من تاريخها، وزرُّ تمديد» — على صفحة اللوحة الحقيقيّة، قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/banner_extend_proposal.mjs
//
// انتهت مدّةُ لافتات صاحب المنصّة في منتصف الليل فغابت من التطبيق، واللوحةُ
// بقيت تقول «جارية»: تقرأ عمودَ الحالة، وهو لا يتبدّل إلّا مرّةً في اليوم.
// فتُفتح «الاشتراكات والإعلانات» في وضع العرض، ويُرسم على صفوفها الحقيقيّة —
// **(أ)**: الحالةُ من التاريخ («انتهت مدّتها»)، وتنبيهُ «تنتهي خلال يومين»،
// وزرُّ «تمديد» بجانب «إلغاء»؛ ثمّ نافذةُ التمديد **مرسومةً** بعناصر اللوحة.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/banner-extend-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4796)
const base = 'http://localhost:4796'

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

// الصفُّ الأوّل: انتهت مدّتُه وما زال عمودُه «جارية» — فيُقال «انتهت مدّتها».
// والثاني: جارٍ وينتهي بعد يومين — فيُنبَّه تحت فترته. وكلاهما يُمدَّد.
const mark = () => {
  const rows = [...document.querySelectorAll('tbody tr')].filter((r) => /جارية/.test(r.innerText))
  const ended = [...document.querySelectorAll('tbody tr')].find((r) => /منتهية/.test(r.innerText))
  const endedBadge = ended?.querySelector('td:nth-child(7) > *')
  const say = (row, period, badgeText) => {
    const cells = row.querySelectorAll('td')
    cells[2].innerHTML = period
    if (badgeText && endedBadge) {
      const b = endedBadge.cloneNode(true)
      const walker = document.createTreeWalker(b, NodeFilter.SHOW_TEXT)
      let node
      while ((node = walker.nextNode())) if (node.textContent.trim()) node.textContent = badgeText
      cells[6].replaceChildren(b)
    }
    const cancel = cells[7].querySelector('button')
    if (cancel) {
      const extend = cancel.cloneNode(true)
      extend.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2v4M16 2v4M3 10h18M12 14v4M10 16h4"/><rect x="3" y="4" width="18" height="18" rx="2"/></svg>تمديد'
      extend.style.color = 'var(--accent)'
      extend.style.fontWeight = '600'
      cells[7].style.whiteSpace = 'nowrap'
      cells[7].prepend(extend)
    }
  }
  if (rows[0]) say(rows[0], '7 سبتمبر 2026 — 7 أكتوبر 2026<span style="display:block;font-size:11px;color:var(--critical)">انتهت قبل ساعة — لا تظهر في التطبيق</span>', 'انتهت مدّتها')
  if (rows[1]) say(rows[1], '12 سبتمبر 2026 — 10 أكتوبر 2026<span style="display:block;font-size:11px;color:var(--warning);font-weight:600">تنتهي خلال يومين</span>', null)
  rows[0]?.scrollIntoView({ block: 'center' })
}

await page.evaluate(`(${mark})()`)
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/banner-1-table.png` })

// نافذةُ التمديد — مرسومة: ثلاثةُ أزرارٍ سريعة، أو تاريخٌ بعينه، وما سيصير.
const dialog = () => {
  const veil = document.createElement('div')
  veil.style.cssText = 'position:fixed;inset:0;background:rgba(40,10,20,.45);display:grid;place-items:center;z-index:99'
  veil.innerHTML = `
  <div data-theme="light" style="width:440px;background:var(--surface,#fff);border:1px solid var(--hairline);border-radius:18px;padding:22px;box-shadow:0 20px 50px rgba(0,0,0,.25);font-size:14px;color:var(--ink)">
    <div style="font-size:17px;font-weight:700;margin-bottom:4px">تمديد اللافتة</div>
    <div style="font-size:12px;color:var(--text-muted);margin-bottom:16px">الصورُ والكلماتُ والمزوّدُ تبقى كما هي — يتغيّر تاريخُ النهاية وحدَه.</div>
    <div style="font-size:12px;color:var(--ink-2);margin-bottom:8px">مدّدها</div>
    <div style="display:flex;gap:8px;margin-bottom:14px">
      ${['7 أيام', '30 يوماً', '90 يوماً'].map((t, i) => `<span style="flex:1;text-align:center;padding:9px 0;border-radius:12px;border:1px solid ${i === 1 ? 'var(--accent)' : 'var(--hairline)'};${i === 1 ? 'background:var(--accent);color:#fff;font-weight:600' : ''}">${t}</span>`).join('')}
    </div>
    <div style="font-size:12px;color:var(--ink-2);margin-bottom:6px">أو حتى تاريخ</div>
    <div style="border:1px solid var(--hairline);border-radius:12px;padding:10px 12px;margin-bottom:16px;direction:ltr;text-align:right">2026-11-07</div>
    <div style="background:var(--gold-soft,#f7efe0);border-radius:12px;padding:10px 12px;font-size:13px;margin-bottom:18px">
      تنتهي <b>7 نوفمبر 2026</b> آخرَ اليوم — وتعود إلى التطبيق فوراً.
    </div>
    <div style="display:flex;gap:8px;justify-content:flex-start">
      <span style="padding:9px 22px;border-radius:12px;background:var(--accent);color:#fff;font-weight:600">مدّد</span>
      <span style="padding:9px 18px;border-radius:12px;border:1px solid var(--hairline)">إلغاء</span>
    </div>
  </div>`
  document.body.append(veil)
}
await page.evaluate(`(${dialog})()`)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/banner-2-extend.png` })

await browser.close()
server.close()
