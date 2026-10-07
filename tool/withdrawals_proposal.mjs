// **مقترحُ «طلبات السحب» في اللوحة — مرسومٌ بأصناف اللوحة، قبل التنفيذ.**
//
//   npm run build && SHOTS=<مجلّد> node tool/withdrawals_proposal.mjs
//
// الصفحةُ غيرُ موجودة، فتُرسم: تُفتح «عمليات الدفع» الحقيقيّة في وضع العرض،
// ويُستبدل محتواها بجدولٍ من صفوفها نفسِها — فالبطاقةُ ورأسُ الجدول والشاراتُ
// والأزرارُ بأصنافها في اللوحة، والنصوصُ مقترحة.
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright-core'

const dist = path.resolve('dist')
const out = process.env.SHOTS ?? '/tmp/withdrawals-proposal'
fs.mkdirSync(out, { recursive: true })
const types = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.svg': 'image/svg+xml' }
const server = http.createServer((req, res) => {
  let p = path.join(dist, decodeURIComponent(req.url.split('?')[0]))
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(dist, 'index.html')
  res.writeHead(200, { 'content-type': types[path.extname(p)] ?? 'application/octet-stream' })
  fs.createReadStream(p).pipe(res)
}).listen(4794)
const base = 'http://localhost:4794'

const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const page = await browser.newPage({ viewport: { width: 1366, height: 860 } })
await page.goto(`${base}/#/login`)
await page.waitForTimeout(900)
await page.fill('input[type=email]', 'owner@sdd.company')
await page.fill('input[type=password]', 'demo-password')
await page.click('button[type=submit]')
await page.waitForTimeout(1300)
await page.goto(`${base}/#/payments`)
await page.waitForTimeout(1600)

await page.evaluate(() => {
  // [الطلب، العميل، من أين الرصيد، المبلغ، الوسيلة، ما أدخله العميل، ما في سجلّ الدفع، التاريخ، الحال]
  const rows = [
    ['WD-2026-0007', 'بلقيس الحضرمي', 'BK-2026-000318 · إلغاء', '120,000 ر.ي', 'جوالي', '777 123 456', '777 123 456', '6 أكتوبر', 'warning'],
    ['WD-2026-0006', 'أحمد الشرعي', 'BK-2026-000270 · رفض المزوّد', '255,000 ر.ي', 'الكريمي', '3009 876 543', '3001 234 567', '5 أكتوبر', 'warning'],
    ['WD-2026-0005', 'فاطمة الصنعاني', 'BK-2026-000244 · إلغاء', '40,000 ر.ي', 'جوالي', '771 998 210', '771 998 210', '2 أكتوبر', 'good'],
  ]
  document.querySelector('[data-page-title]')?.replaceChildren('طلبات السحب')
  const table = document.querySelector('table')
  const card = table.closest('.glass-panel')
  // ما سوى بطاقة الجدول يُخفى: المرشّحاتُ والأرقامُ والرسمُ صفحةٌ أخرى.
  const content = card.parentElement
  for (const el of [...content.children]) if (el !== card) el.style.display = 'none'
  const pill = document.querySelector('tbody span[class*="rounded-full"]')
  const badgeClass = pill?.className ?? ''
  const th = table.querySelector('thead th')
  const thClass = th.className
  table.querySelector('thead tr').innerHTML = ['الطلب', 'العميل', 'المبلغ', 'دفع منه — أدخله العميل', 'في سجلّ الدفع', 'الإجراء']
    .map((h) => `<th class="${thClass}">${h}</th>`).join('')
  const td = 'px-4 py-3 text-xs whitespace-nowrap text-ink-2'
  table.querySelector('tbody').innerHTML = rows.map(([ref, who, from, amt, to, num, paid, date, tone]) => `
    <tr class="glass-row border-b border-hairline">
      <td class="px-4 py-3 whitespace-nowrap"><span class="font-medium text-ink" dir="ltr">${ref}</span><span class="block text-[11px] text-muted">${date}</span></td>
      <td class="${td}">${who}<span class="block text-[11px] text-muted" dir="ltr">${from}</span></td>
      <td class="${td} font-semibold text-ink">${amt}</td>
      <td class="${td}">${to} <span dir="ltr" class="font-semibold text-ink">${num}</span></td>
      <td class="${td}"><span dir="ltr">${paid}</span>
        <span class="ms-1 inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-semibold" style="${num === paid
          ? 'color:var(--good);border-color:color-mix(in oklab,var(--good) 40%,transparent);background:color-mix(in oklab,var(--good) 10%,var(--surface))'
          : 'color:var(--critical);border-color:color-mix(in oklab,var(--critical) 40%,transparent);background:color-mix(in oklab,var(--critical) 10%,var(--surface))'}">${num === paid ? '✓ مطابق' : '✗ غير مطابق'}</span></td>
      <td class="px-4 py-3 whitespace-nowrap">${tone === 'good' ? `<span class="${badgeClass}">حُوِّل</span>` : `
        <button class="btn-glass rounded-[10px] px-3 py-1.5 text-xs font-semibold">حوّلتُ المبلغ</button>
        <button class="rounded-[10px] border border-hairline px-3 py-1.5 text-xs text-ink-2">رفض</button>`}</td>
    </tr>`).join('')
  const head = document.createElement('header')
  head.className = 'flex flex-wrap items-start justify-between gap-3 border-b border-hairline px-4 py-3 sm:px-5'
  head.innerHTML = '<div><h2 class="text-sm font-semibold text-ink">طلباتُ سحب «رصيد فرحتي»</h2><p class="mt-0.5 text-xs text-muted">قارِن الرقمَ الذي أدخله العميل بما في سجلّ دفعه، ثمّ حوِّل إليه واضغط «حوّلتُ المبلغ»</p></div>'
  card.prepend(head)
  // ترقيمُ الصفحات لعمليات الدفع لا لهذه.
  for (const el of card.children) if (el !== head && !el.contains(table)) el.style.display = 'none'
})
await page.mouse.move(5, 5)
await page.waitForTimeout(400)
await page.screenshot({ path: `${out}/withdrawals.png` })
await browser.close()
server.close()
