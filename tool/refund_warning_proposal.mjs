// **مقترحٌ لا تنفيذ.** تنبيهُ «هذا المبلغُ دُفع للمزوّد» في حوار استرجاع
// المبلغ — وهو اختيارُ صاحب المنصّة (أ): يمضي الردُّ ويُنبَّه، لا يُحبَس.
//
//   npm run dev -- --port 5178 --host 127.0.0.1   # في نافذةٍ أخرى
//   node tool/refund_warning_proposal.mjs /tmp/shots
//
// ولا شيءَ في `src/` تغيّر.
//
// ── ولماذا التنبيه ─────────────────────────────────────────────────────────
//
// `settlements.sql` يحسب مستحقَّ المزوّد من `paid_amount - refunded_amount`
// في **الحجز**. ومستحقٌّ **دُفع** لا يستردُّه شيء: `not exists
// settlement_items` يمنع إعادة الاحتساب. فمن ردَّ بعد الدفع ردَّ من جيب
// المنصّة — **ويجب أن يعلم ذلك قبل أن يضغط لا بعده.**
//
// ── وما هو حقيقيٌّ في هذه اللقطات وما هو مرسوم ─────────────────────────────
//
// **الحوارُ حقيقيّ:** `ConfirmDialog` المشحون يُفتح بضغط زرّ الاسترجاع في
// صفحة «المدفوعات» الحقيقيّة — إطارُه وخطوطُه وأزرارُه وعنوانُه ونصُّه
// كلُّها من اللوحة.
//
// **والمرسومُ سطرُ التنبيه وحدَه:** يُحقن في الحوار بالـDOM. ولا خدمةَ
// تردُّه ولا `api_refund_outlook` تُستدعى — تلك في القاعدة ومدفوعة.
//
// ثلاثُ لقطات، لأنّ الفرقَ بينها هو السؤال:
//   ١) اليومَ — الحوارُ كما هو، لا ذكرَ للتسوية.
//   ٢) والمقترحُ حين تكون التسويةُ **قد دُفعت** — تنبيهٌ أحمر.
//   ٣) والمقترحُ حين تكون **قيد الاحتساب** — تنبيهٌ أخفّ: ما زال يُعدَّل.
import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const PORT = 9334
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

// **والمرساةُ لا المسار:** اللوحةُ `HashRouter`. و`/payments` تعرض الجذر.
await evaluate(`(() => {
  const a = [...document.querySelectorAll('a')]
    .find((x) => x.getAttribute('href') === '#/payments')
  if (!a) throw new Error('لا رابطَ للمدفوعات')
  a.click()
})()`)
await sleep(4500)

// ── يُفتح الحوارُ الحقيقيُّ بزرّ الاسترجاع الحقيقيّ ─────────────────────────
const opened = await evaluate(`(() => {
  const btn = [...document.querySelectorAll('button')]
    .find((b) => b.textContent.trim().includes('استرجاع'))
  if (!btn) return 'لا زرَّ استرجاع — لعلّ الصفحةَ لم تُحمَّل'
  btn.click()
  return 'فُتح'
})()`)
console.log('·', opened)
await sleep(1200)

const dialogClip = async () => {
  const box = await evaluate(`(() => {
    const heads = [...document.querySelectorAll('h1,h2,h3,p,div')]
      .filter((e) => e.textContent.trim().startsWith('استرجاع المبلغ للعميل'))
    const title = heads[heads.length - 1]
    if (!title) return null
    let card = title
    for (let i = 0; i < 8 && card.parentElement; i++) {
      card = card.parentElement
      const r = card.getBoundingClientRect()
      if (r.width > 340 && r.width < 900 && r.height > 140) break
    }
    const r = card.getBoundingClientRect()
    return JSON.stringify({
      // **واللقطةُ تسع الحوارَ كلَّه.** قُصّ «تنفيذ الاسترجاع» من حافّته
      // في أوّل رسمٍ فبدا الزرُّ ناقصاً — وهو الزرُّ الذي يُسأل عنه.
      x: Math.max(0, r.left - 40), y: Math.max(0, r.top - 24),
      // **والقصُّ يشمل الأزرار.** لقطةٌ تقطع «تنفيذ الاسترجاع» تُري
      // التنبيهَ ولا تُري ما سيُضغط بعده — وهو نصفُ السؤال.
      width: Math.min(r.width + 80, 1500), height: r.height + 72,
    })
  })()`)
  return box ? JSON.parse(box) : null
}

const shoot = async (name) => {
  const clip = await dialogClip()
  if (!clip) throw new Error(`لم يُعثر على الحوار — ${name}`)
  const { result } = await send('Page.captureScreenshot', {
    format: 'png', clip: { ...clip, scale: 1 },
  })
  writeFileSync(`${OUT}/${name}`, Buffer.from(result.data, 'base64'))
  console.log('✓', name)
}

await shoot('refund-today.png')

// ── ثمّ يُحقن سطرُ التنبيه — **وهو المرسومُ وحدَه** ─────────────────────────
const inject = async (tone) => {
  await evaluate(`(() => {
    document.getElementById('sdd-warn')?.remove()
    const heads = [...document.querySelectorAll('h1,h2,h3,p,div')]
      .filter((e) => e.textContent.trim().startsWith('استرجاع المبلغ للعميل'))
    const title = heads[heads.length - 1]
    const body = [...title.parentElement.children]
      .find((e) => e !== title && e.textContent.length > 40) || title

    const paid = ${tone === 'paid'}
    const box = document.createElement('div')
    box.id = 'sdd-warn'
    box.dir = 'rtl'
    box.style.cssText = [
      'margin-top:14px', 'padding:12px 14px', 'border-radius:12px',
      'font-size:14px', 'line-height:1.85', 'display:flex', 'gap:10px',
      'align-items:flex-start',
      paid ? 'background:#fdf2f2' : 'background:#fdf8ee',
      paid ? 'color:#8a1c1c' : 'color:#7a5312',
      paid ? 'border:1px solid #f0c9c9' : 'border:1px solid #efdcb4',
    ].join(';')
    box.innerHTML = paid
      ? '<span style="font-size:17px;line-height:1.35">⚠️</span><span>' +
        '<b>هذا المبلغُ دُفع لمقدّم الخدمة</b> في التسوية ' +
        '<span style="font-family:monospace;direction:ltr;unicode-bidi:isolate;white-space:nowrap">STL-202609-4A7C21</span>' +
        ' بتاريخ ٣ سبتمبر. الاسترجاعُ يمضي، <b>ويُخصم من المنصّة</b> — ' +
        'وسوِّ الفرقَ مع مقدّم الخدمة بنفسك.</span>'
      : '<span style="font-size:17px;line-height:1.35">ℹ️</span><span>' +
        'لهذا الحجز مستحقٌّ <b>قيد الاحتساب</b> لم يُدفع بعد ' +
        '(<span style="font-family:monospace;direction:ltr;unicode-bidi:isolate;white-space:nowrap">STL-202609-4A7C21</span>)' +
        '. سيُعدَّل تلقائياً بعد الاسترجاع.</span>'
    body.insertAdjacentElement('afterend', box)
  })()`)
  await sleep(350)
}

await inject('paid')
await shoot('refund-warn-paid.png')

await inject('pending')
await shoot('refund-warn-pending.png')

ws.close()
chrome.kill()
console.log('\nتمّت اللقطاتُ الثلاث في', OUT)
