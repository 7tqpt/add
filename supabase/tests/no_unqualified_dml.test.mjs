/**
 * لا `delete` ولا `update` بلا شرط `WHERE` **داخل أجساد الدوال**.
 *
 * لماذا فحصٌ للنصّ لا للسلوك؟ لأن المنع لا يقع عندنا بل عند Supabase: مشاريعه
 * تحمّل إضافة `pg-safeupdate` على أدوار الـAPI فترفض كل `DELETE` أو `UPDATE`
 * بلا شرط برمز 21000. وPGlite التي نختبر عليها لا تحمل تلك الإضافة، فالجملة
 * تنجح هنا وتُرفض هناك — وهذا أسوأ أنواع الفجوات: اختبارٌ أخضر وواجهةٌ معطّلة.
 *
 * ولماذا أجسادُ الدوال وحدها؟ لأنها هي التي يستدعيها التطبيق بجلسة المستخدم،
 * فتخضع للإضافة. أمّا جُمل الملفّات نفسها — تنظيفُ `seed.sql` مثلاً — فتُنفَّذ
 * في محرّر SQL بدور `postgres`، ولا تُحمَّل الإضافة عليه. فمنعُها هنا تحذيرٌ
 * كاذب، والتحذير الكاذب يُعلّم القارئ أن يتجاهل الحارس.
 *
 * و`truncate` مستثناةٌ: ليست `DELETE` فلا تمرّ بالإضافة أصلاً، وهي التصريح
 * الصريح عن «أفرغ الجدول» بدل الالتفاف بشرطٍ صوريّ يخدع الحماية.
 */
import { readdirSync, readFileSync } from 'node:fs'

const dir = new URL('../', import.meta.url)
const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()

/** أجسادُ الدوال وحدها — بين علامتَي اقتباسٍ بالدولار. */
function bodies(sql) {
  const out = []
  const re = /\$([a-z_]*)\$([\s\S]*?)\$\1\$/gi
  let m
  while ((m = re.exec(sql)) !== null) out.push(m[2])
  return out
}

/** يُزيل التعليقات والنصوص المقتبسة حتى لا تُقرأ كأنها جُمل. */
function strip(sql) {
  return sql
    .replace(/--[^\n]*/g, ' ')
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/'(?:[^']|'')*'/g, "''") // النصوص تصير فارغة فلا تُخفي فاصلةً منقوطة
}

const PATTERNS = [
  { verb: 'delete', re: /\bdelete\s+from\s+([a-z0-9_."]+)([^;]*);/gi },
  { verb: 'update', re: /\bupdate\s+(?:only\s+)?([a-z0-9_."]+)\s+set\b([^;]*);/gi },
]

let fail = 0
const findings = []

let scanned = 0
for (const file of files) {
  for (const body of bodies(readFileSync(new URL(file, dir), 'utf8'))) {
    scanned++
    const sql = strip(body)
    for (const { verb, re } of PATTERNS) {
      re.lastIndex = 0
      let m
      while ((m = re.exec(sql)) !== null) {
        const [, table, tail] = m
        if (/\bwhere\b/i.test(tail)) continue
        findings.push({ file, verb, table })
      }
    }
  }
}

console.log(`فُحص ${scanned} جسد دالة في ${files.length} ملفّ SQL\n`)

if (findings.length === 0) {
  console.log('✅ كل جُمل delete و update مشروطة')
} else {
  fail = findings.length
  for (const f of findings) {
    console.log(`❌ ${f.file}: ${f.verb} على ${f.table} بلا WHERE`)
  }
  console.log(
    '\n‏Supabase سيرفضها برمز 21000. اشترط WHERE، أو استعمل truncate إن كان' +
      ' إفراغ الجدول هو المقصود صراحةً.',
  )
}

if (fail) process.exit(1)
console.log('\n🎉 لا جملةَ تُرفض عند Supabase وتنجح عندنا.')
