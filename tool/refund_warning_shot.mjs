// **تصويرُ ما صار.** لا مقترحَ ولا حقنَ DOM: الشريطُ المشحونُ من
// `SettlementNotice` في `src/pages/Payments.tsx`، يُعرضه الحوارُ نفسُه بعد
// أن تردَّ `refundOutlook` من بيانة العرض.
//
//   npm run dev -- --port 5178 --host 127.0.0.1   # في نافذةٍ أخرى
//   node tool/refund_warning_shot.mjs /tmp/shots
//
// **ولا يُصدَّق أنّ الشريطَ ظهر لأنّه رُسم: تُسأل الصفحة.** يُقرأ نصُّه من
// الشجرة قبل اللقطة، فلو لم يُعرض سقط الراسمُ ولم يُخرج صورةً تُطمئن.
import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const PORT = 9335
const BASE = 'http://127.0.0.1:5178'
const OUT = process.argv[2] || '/tmp/shots'

const chrome = spawn('/opt/pw-browsers/chromium-1194/chrome-linux/chrome', [
  '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
  `--remote-debugging-port=${PORT}`, '--window-size=1500,1000',
  '--force-device-scale-factor=2', 'about:blank',
], { stdio: 'ignore' })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

let up = false
for (let i = 0; i < 40 && !up; i++) {
  try { await fetch(`http://127.0.0.1:${PORT}/json/version`); up = true }
  catch { await sleep(250) }
}
if (!up) throw new Error('لم يبدأ Chromium')

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
  if (r.result?.exceptionDetails) {
    throw new Error(r.result.exceptionDetails.exception?.description ?? 'خطأ')
  }
  return r.result?.result?.value
}

await send('Page.enable')
await send('Runtime.enable')
await send('Emulation.setDeviceMetricsOverride', {
  width: 1500, height: 1000, deviceScaleFactor: 2, mobile: false,
})

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
  .find((x) => x.getAttribute('href') === '#/payments').click()`)
await sleep(4500)

const clip = async () => {
  const box = await evaluate(`(() => {
    const d = document.querySelector('dialog[open]')
    if (!d) return null
    const r = d.getBoundingClientRect()
    return JSON.stringify({
      x: Math.max(0, r.left - 32), y: Math.max(0, r.top - 32),
      width: Math.min(r.width + 64, 1500), height: r.height + 64,
    })
  })()`)
  return box ? JSON.parse(box) : null
}

// يُفتح الحوارُ على كلّ دفعةٍ ناجحةٍ حتى يُعثر على واحدةٍ لمزوّدٍ سُوّي له،
// لأنّ الشريطَ لا يظهر إلّا حينها — وهو المقصودُ بالتصوير.
let shots = 0
const seen = new Set()
for (let i = 0; i < 14 && shots < 2; i++) {
  const opened = await evaluate(`(() => {
    const btns = [...document.querySelectorAll('button')]
      .filter((b) => b.textContent.trim().includes('استرجاع'))
    const b = btns[${i}]
    if (!b) return 'انتهت الأزرار'
    b.click()
    return 'فُتح'
  })()`)
  if (opened !== 'فُتح') break
  await sleep(1400)

  const tone = await evaluate(`(() => {
    const d = document.querySelector('dialog[open]')
    if (!d) return 'لا حوار'
    const t = d.textContent
    if (t.includes('دُفع لمقدّم الخدمة')) return 'paid'
    if (t.includes('قيد الاحتساب')) return 'pending'
    return 'none'
  })()`)

  if (tone !== 'none' && !seen.has(tone)) {
    const c = await clip()
    const { result } = await send('Page.captureScreenshot', {
      format: 'png', clip: { ...c, scale: 1 },
    })
    writeFileSync(`${OUT}/refund-shipped-${tone}.png`, Buffer.from(result.data, 'base64'))
    console.log('✓', `refund-shipped-${tone}.png`)
    seen.add(tone)
    shots++
  }

  await evaluate(`(() => {
    const d = document.querySelector('dialog[open]')
    const cancel = [...d.querySelectorAll('button')]
      .find((b) => b.textContent.trim() === 'إلغاء')
    cancel?.click()
  })()`)
  await sleep(500)
}

if (shots === 0) {
  throw new Error('لم يظهر الشريطُ في أيّ حوار — لم يُصوَّر شيءٌ يُطمئن')
}

ws.close()
chrome.kill()
console.log(`\nصُوِّر ${shots} من الشريط المشحون في`, OUT)
