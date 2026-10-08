// **مقترحُ الموافقة على الخدمات (ج) — على صفحات اللوحة الحقيقيّة، قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/service_approval_proposal.mjs
//
// قال صاحبُ المنصّة: «مقدم الخدمة يختار القسم الذي يبغى بس لايمكنه تغيير الي
// بعلم الادارة»، واختار (ج): الإدارةُ توافق **بإضافة القسم له** («تغيير القسم»)
// **وعلى كلّ خدمةٍ وحدَها** («موافقة» و«رفض»). فيُرسم — **مرسوماً** فوق صفحاتٍ
// حقيقيّةٍ في وضع العرض —:
//   ١. في «مقدّمو الخدمة»: بطاقةُ «خدماتٌ بانتظار موافقتك» تجمعها من كلّ المزوّدين.
//   ٢. في صفحة المزوّد: شارةُ «بانتظار الموافقة» وزرّاها على الخدمة نفسها.
//   ٣. ونافذةُ الرفض بسببٍ يصل المزوّد.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/service-approval-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4799)
const base = 'http://localhost:4799'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1300)



const btn = (label, primary) => `<button style="display:inline-flex;align-items:center;gap:4px;padding:5px 12px;border-radius:10px;font-size:12px;font-weight:600;${primary ? 'background:var(--accent);color:#fff;border:0' : 'background:var(--surface);color:var(--ink);border:1px solid var(--border)'}">${label}</button>`
const pill = (label) => `<span style="display:inline-flex;align-items:center;gap:4px;border-radius:999px;padding:2px 9px;font-size:12px;white-space:nowrap;border:1px solid color-mix(in oklab,var(--warning) 50%,transparent);background:color-mix(in oklab,var(--warning) 14%,transparent);color:color-mix(in oklab,var(--warning) 55%,var(--text-primary))">⏳ ${label}</span>`

// ١. قائمةُ المزوّدين وفوقها البطاقة.
await page.goto(`${base}/#/providers`)
await page.waitForTimeout(1500)
await page.evaluate(({ btnSrc, pillSrc }) => {
  const btn = eval(btnSrc), pill = eval(pillSrc)
  const table = document.querySelector('main table')?.closest('.glass-panel, [class*="rounded"]')
  const host = table?.parentElement
  const card = document.createElement('section')
  card.style.cssText = 'background:var(--surface);border:1px solid var(--border);border-radius:16px;margin-bottom:16px;overflow:hidden'
  const rows = [
    ['تصوير حفلات — باقة كاملة', 'قاعة الأصالة', 'التصوير والإضاءة', 'القاعات والخيام', '150,000 ر.ي', 'منذ ساعتين'],
    ['ضيافة قهوة وحلا', 'قاعة الأصالة', 'الطبخ والضيافة', 'القاعات والخيام', '80,000 ر.ي', 'منذ ساعتين'],
    ['زفّة بالطبول', 'استوديو السعادة', 'الفنانين والفرق', 'التصوير والإضاءة', '60,000 ر.ي', 'أمس'],
  ]
  card.innerHTML = `
    <div style="padding:16px 18px 10px;display:flex;justify-content:space-between;align-items:flex-end;gap:12px">
      <div><div style="font-size:15px;font-weight:700;color:var(--ink)">خدماتٌ بانتظار موافقتك <span style="font-size:12px;color:var(--text-muted);font-weight:500">(3)</span></div>
      <div style="font-size:12px;color:var(--text-muted);margin-top:2px">أضافها مقدّمو خدمة في قسمٍ ليس من أقسامهم — لا يراها العملاءُ حتى توافق.</div></div>
    </div>
    <table style="width:100%;border-collapse:collapse;font-size:12.5px">
      <thead><tr>${['الخدمة', 'مقدّم الخدمة', 'قسمُها', 'أقسامُه', 'السعر', '', ''].map((h) => `<th style="text-align:start;padding:8px 16px;color:var(--gold-ink, #8a5f14);font-weight:500;border-top:1px solid var(--border);border-bottom:1px solid var(--border)">${h}</th>`).join('')}</tr></thead>
      <tbody>${rows.map((r) => `<tr style="border-bottom:1px solid var(--border)">
        <td style="padding:10px 16px;color:var(--ink);font-weight:600">${r[0]}<span style="display:block;font-size:11px;color:var(--text-muted);font-weight:400">${r[5]}</span></td>
        <td style="padding:10px 16px;color:var(--ink)">${r[1]}</td>
        <td style="padding:10px 16px">${pill(r[2])}</td>
        <td style="padding:10px 16px;color:var(--text-muted)">${r[3]}</td>
        <td style="padding:10px 16px;color:var(--ink);white-space:nowrap">${r[4]}</td>
        <td style="padding:10px 16px;white-space:nowrap;display:flex;gap:6px">${btn('✓ موافقة', true)}${btn('✕ رفض')}</td>
        <td style="padding:10px 16px;white-space:nowrap"><a style="font-size:12px;color:var(--accent);text-decoration:underline">أضف «${r[2]}» لأقسامه</a></td>
      </tr>`).join('')}</tbody>
    </table>`
  host?.insertBefore(card, host.firstChild)
  card.scrollIntoView({ block: 'start' })
}, { btnSrc: btn.toString(), pillSrc: pill.toString() })
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/approval-1-list.png` })

// ٢. صفحةُ مزوّدٍ له خدمات — الصفُّ الثاني بانتظار الموافقة.
const hrefs = await page.locator('tbody a[href*="#/providers/"]').evaluateAll((as) => as.map((a) => a.getAttribute('href')))
for (const href of hrefs) {
  await page.goto(`${base}/${href}`)
  await page.waitForTimeout(1200)
  if (await page.locator('[data-outside-line]').count()) break
}
await page.evaluate(({ btnSrc, pillSrc }) => {
  const btn = eval(btnSrc), pill = eval(pillSrc)
  const note = document.querySelector('[data-outside-note]')
  if (note) note.innerHTML = '<b style="color:color-mix(in oklab,var(--warning) 55%,var(--text-primary))">خدمةٌ بانتظار موافقتك</b> — في قسمٍ ليس من أقسامه. وافق عليها وحدَها، أو أضف قسمَها له من «تغيير القسم» فتُقبل خدماتُه فيه كلُّها.'
  if (note) note.style.background = 'color-mix(in oklab,var(--warning) 12%,transparent)'
  const line = document.querySelector('[data-outside-line]')
  if (line) { line.textContent = 'في «التصوير والإضاءة» — ليس من أقسامه'; line.style.color = 'color-mix(in oklab,var(--warning) 55%,var(--text-primary))' }
  const cell = line?.closest('tr')?.querySelector('[data-service-state]')
  if (cell) cell.innerHTML = `<div style="display:flex;flex-direction:column;gap:6px;align-items:flex-start">${pill('بانتظار الموافقة')}<div style="display:flex;gap:6px">${btn('✓ موافقة', true)}${btn('✕ رفض')}</div></div>`
  line?.scrollIntoView({ block: 'center' })
}, { btnSrc: btn.toString(), pillSrc: pill.toString() })
await page.mouse.move(5, 5)
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/approval-2-provider.png` })

// ٣. نافذةُ الرفض.
await page.evaluate(() => {
  const veil = document.createElement('div')
  veil.style.cssText = 'position:fixed;inset:0;background:rgba(40,10,20,.45);display:grid;place-items:center;z-index:99'
  veil.innerHTML = `
  <div style="width:440px;background:var(--surface,#fff);border:1px solid var(--border);border-radius:18px;padding:22px;box-shadow:0 20px 50px rgba(0,0,0,.25);font-size:14px;color:var(--ink)">
    <div style="font-size:17px;font-weight:700;margin-bottom:6px">رفض «تصوير حفلات — باقة كاملة»؟</div>
    <div style="font-size:12px;color:var(--text-muted);line-height:1.8;margin-bottom:12px">تبقى مخفيّةً عن العملاء، ويصل مقدّمَ الخدمة إشعارٌ بالسبب. ويستطيع أن يعدّلها فتعود إليك للمراجعة.</div>
    <div style="font-size:12px;color:var(--ink-2);margin-bottom:6px">سبب الرفض</div>
    <div style="border:1px solid var(--border);border-radius:12px;padding:10px 12px;min-height:64px;margin-bottom:18px">التصويرُ خارج نشاط القاعة — سجّل مقدّمَ خدمةٍ آخر للتصوير.</div>
    <div style="display:flex;gap:8px">
      <span style="padding:9px 22px;border-radius:12px;background:var(--critical);color:#fff;font-weight:600">ارفض</span>
      <span style="padding:9px 18px;border-radius:12px;border:1px solid var(--border)">إلغاء</span>
    </div>
  </div>`
  document.body.append(veil)
})
await page.waitForTimeout(300)
await page.screenshot({ path: `${out}/approval-3-reject.png` })

await browser.close()
server.close()
