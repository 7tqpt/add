// **مقترحٌ لا تنفيذ.** مراجعةُ الإدارة لتنفيذ الحجز، ومكانُها الذي اختاره
// صاحبُ المنصّة: **(ب) مرشِّحٌ داخل صفحة «الحجوزات» الموجودة**.
//
//   npm run dev -- --port 5178 --host 127.0.0.1   # في نافذةٍ أخرى
//   node tool/bookings_review_proposal.mjs /tmp/shots
//
// ── ولماذا لا Playwright ────────────────────────────────────────────────────
//
// لا Playwright في هذه البيئة، و Chromium موجودٌ في `/opt/pw-browsers`.
// فيُقاد بـCDP مباشرةً، و`WebSocket` مبنيٌّ في Node منذ الثانية والعشرين.
//
// ── واللوحةُ موجِّهُها بالمِرساة ─────────────────────────────────────────────
//
// `#/bookings` لا `/bookings`. وقد صُوّرت «لوحةُ المعلومات» ثلاثَ مرّاتٍ
// ظنّاً أنّها «الحجوزات» قبل أن يُعرف ذلك: المسارُ يقول `/bookings`
// والمرساةُ فارغةٌ فيُعرض الجذر.
//
// لقطتان لصفحة «الحجوزات» في لوحة التحكّم:
//
//   ١) اليومَ — مصوَّرةٌ من اللوحة الحقيقيّة تعمل في وضع العرض.
//   ٢) والمقترحُ — **مرسومٌ فوق الصفحة الحقيقيّة نفسِها**: يُضاف خيارٌ إلى
//      مرشِّح الحالات وتُبدَّل صفوفُ الجدول بالـDOM. فالإطارُ والخطوطُ
//      والألوانُ كلُّها من اللوحة لا من رسمٍ يشبهها — **والصفوفُ نفسُها
//      مرسومةٌ ويُقال**.
import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const PORT = 9333
const BASE = 'http://127.0.0.1:5178'
const OUT = process.argv[2] || '/tmp/shots'

const chrome = spawn('/opt/pw-browsers/chromium-1194/chrome-linux/chrome', [
  '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
  `--remote-debugging-port=${PORT}`, '--window-size=1700,1000',
  '--force-device-scale-factor=2', 'about:blank',
], { stdio: 'ignore' })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

let ok = false
for (let i = 0; i < 40 && !ok; i++) {
  try { await fetch(`http://127.0.0.1:${PORT}/json/version`); ok = true }
  catch { await sleep(250) }
}
if (!ok) throw new Error('لم يبدأ Chromium')

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()
const ws = new WebSocket(list.find((t) => t.type === 'page').webSocketDebuggerUrl)
await new Promise((r) => (ws.onopen = r))

let id = 0
const pending = new Map()
ws.onmessage = (e) => {
  const m = JSON.parse(e.data)
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id) }
}
const send = (method, params = {}) => new Promise((resolve) => {
  const n = ++id
  pending.set(n, resolve)
  ws.send(JSON.stringify({ id: n, method, params }))
})
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true })
  return r.result?.result?.value
}

await send('Page.enable')
await send('Runtime.enable')
await send('Emulation.setDeviceMetricsOverride', {
  width: 1700, height: 1000, deviceScaleFactor: 2, mobile: false,
})

// ── الدخولُ من النموذج، كما يدخل صاحبُ اللوحة ───────────────────────────────
await send('Page.navigate', { url: `${BASE}/#/login` })
await sleep(3500)
await evaluate(`(() => {
  const set = (sel, v) => {
    const el = document.querySelector(sel)
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, v)
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }
  set('input[type=email]', 'admin@sdd.company')
  set('input[type=password]', 'demo1234')
  document.querySelector('form').requestSubmit()
})()`)
await sleep(4000)
await evaluate(`[...document.querySelectorAll('a')]
  .find((a) => a.getAttribute('href') === '#/bookings').click()`)
await sleep(5000)

// القائمةُ الجانبيّةُ تُطوى: اللقطةُ للجدول لا للقائمة، وهي تأخذ ثلثَ العرض.
const clipOf = async () => {
  const box = await evaluate(`(() => {
    const t = document.querySelector('table')
    if (!t) return null
    const card = t.closest('div[class*="card"], section, div') || t
    const a = card.getBoundingClientRect()
    const bar = document.querySelector('input[type=search], input[placeholder*="ابحث"]')
    const b = bar ? bar.closest('div').getBoundingClientRect() : a
    const top = Math.min(a.top, b.top) - 18
    return JSON.stringify({
      x: Math.max(0, a.left - 18), y: Math.max(0, top),
      width: a.width + 36, height: a.bottom - top + 60,
    })
  })()`)
  return box ? JSON.parse(box) : null
}

const shoot = async (name) => {
  const clip = await clipOf()
  const { result } = await send('Page.captureScreenshot', {
    format: 'png',
    ...(clip ? { clip: { ...clip, scale: 1 } } : { captureBeyondViewport: true }),
  })
  writeFileSync(`${OUT}/${name}`, Buffer.from(result.data, 'base64'))
  console.log('✓', name)
}

await shoot('dash-bookings-today.png')

// ── ثمّ يُرسم المقترحُ فوق الصفحة نفسِها ────────────────────────────────────
//
// **ويُقال إنّه مرسوم:** لا خدمةَ تردّ هذه الصفوف، ولا زرَّ يفعل شيئاً.
await evaluate(`(() => {
  // ١) خيارٌ جديدٌ في مرشِّح الحالات، ويُختار.
  const select = [...document.querySelectorAll('select')].find((s) =>
    [...s.options].some((o) => o.textContent.includes('بانتظار مقدّم الخدمة')))
  if (select) {
    const opt = document.createElement('option')
    opt.textContent = 'قيد مراجعة التنفيذ'
    opt.value = 'completion_review'
    select.insertBefore(opt, select.options[2] || null)
    select.value = 'completion_review'
  }

  // ٢) صفوفٌ تُبدَّل: طلبا اعتمادٍ ينتظران.
  const tbody = document.querySelector('table tbody')
  if (!tbody) return 'لا جدول'
  const rows = [...tbody.rows]
  const keep = rows.slice(0, 2)
  rows.slice(2).forEach((r) => r.remove())

  const AMBER = '#976113'
  const data = [
    { ref: 'BK-2026-000022', who: 'محمد الوصابي', prov: 'مؤسسة السعادة',
      svc: 'الموية والطليع والخدمات المساندة — باقة متوسطة', sub: 'حضرموت',
      when: '٩ أغسطس ٢٠٢٦', total: '80,000 ر.ي', paid: '80,000 ر.ي' },
    { ref: 'BK-2026-000023', who: 'محمد الوصابي', prov: 'مؤسسة التاج',
      svc: 'متعهدين الحفلات — باقة متوسطة', sub: 'حضرموت',
      when: '٩ أغسطس ٢٠٢٦', total: '800,000 ر.ي', paid: '800,000 ر.ي' },
  ]

  keep.forEach((row, i) => {
    const d = data[i]
    const cells = [...row.cells]
    const put = (idx, html) => { if (cells[idx]) cells[idx].innerHTML = html }
    put(0, '<span style="font-weight:600">' + d.ref + '</span>')
    put(1, d.who)
    put(2, d.prov)
    put(3, d.svc + '<div style="font-size:11px;opacity:.6">' + d.sub + '</div>')
    put(4, d.when)
    put(5, d.total)
    put(6, d.paid)
    // الحالة: شارةٌ كهرمانيّةٌ على شكل شارات اللوحة، وزرّا الاعتماد والرفض.
    put(7,
      '<div style="display:flex;align-items:center;gap:10px;justify-content:flex-end">' +
        '<span style="display:inline-flex;align-items:center;gap:6px;padding:4px 10px;' +
          'border-radius:999px;font-size:12px;font-weight:600;color:' + AMBER + ';' +
          'background:color-mix(in oklab,' + AMBER + ' 12%, transparent);' +
          'border:1px solid color-mix(in oklab,' + AMBER + ' 34%, transparent)">' +
          'قيد مراجعة التنفيذ</span>' +
        '<button style="padding:7px 14px;border-radius:10px;border:0;font-size:12px;' +
          'font-weight:600;color:#fff;background:#0A7A35">اعتماد التنفيذ</button>' +
        '<button style="padding:7px 12px;border-radius:10px;font-size:12px;' +
          'font-weight:600;color:#B3261E;background:transparent;' +
          'border:1px solid color-mix(in oklab,#B3261E 34%, transparent)">رفض</button>' +
      '</div>')
  })
  // وعدّادُ الصفحات يُصحَّح: صفّان معروضان وسبعون في القائمة يكذّبان الصورة.
  // **ولا تعابيرَ نمطيّةً هنا:** هذا النصُّ يمرّ داخل قالبٍ نصّيٍّ إلى
  // المتصفّح، فالشرطةُ المائلةُ المعكوسةُ تُبتلَع ويصير النمطُ شيئاً آخر —
  // وقد وقع ذلك فعلاً فلم يقع التصحيح.
  document.body.querySelectorAll('*').forEach((el) => {
    if (el.children.length) return
    const t = el.textContent.trim()
    if (t.indexOf('عرض') === 0 && t.indexOf('73') > 0) el.textContent = 'عرض ١–٢ من ٢'
    if (t === '1 / 8') el.textContent = '1 / 1'
  })
  return 'رُسم'
})()`).then((v) => console.log('الرسم:', v))

await sleep(600)
await shoot('dash-bookings-proposed.png')

ws.close()
chrome.kill()
process.exit(0)
