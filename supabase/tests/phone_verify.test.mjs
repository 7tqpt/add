/**
 * تحقّقُ رقم الجوال — الحدُّ والإثبات.
 *
 * وأهمُّ ما يُثبَت هنا ثلاثة:
 *
 *   ١) **لا يؤكّد مستخدمٌ رقمَ غيره ولا رقمَ نفسه بلا رمز** — الدالّتان
 *      منزوعتا الصلاحيّة عن المسجَّلين، ولو مُنحت `otp_mark_verified` لهم
 *      لَصار الحاجزُ زينةً: نداءٌ واحدٌ يكفي.
 *   ٢) **والحدُّ يُحسب في القاعدة** — لأنّ كلَّ رسالةٍ مالٌ من رصيد صاحب
 *      المنصّة، ومهلةُ الشاشة تُتجاوز بنداءٍ مباشر.
 *   ٣) **والحجزُ والتسجيلُ في عمليّةٍ واحدة** — «اسأل ثمّ أرسل» تمرّ منه
 *      نداءان متزامنان فيُرسلان معاً.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'phone_verify.sql']) await db.exec(read(f))

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const mustFail = async (label, fn) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    fail++
  } catch (e) {
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 52)}`)
  }
}
const one = async (sql, params) => (await db.query(sql, params)).rows[0]

const A = '11111111-1111-1111-1111-111111111111'
const B = '22222222-2222-2222-2222-222222222222'
await db.exec(`
  insert into auth.users (id, email) values
    ('${A}', 'ayman@aras.ye'), ('${B}', 'nabil@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email, phone, status) values
    ('${A}', 'أيمن', 'ayman@aras.ye', '770000000', 'active'),
    ('${B}', 'نبيل', 'nabil@aras.ye', '771111111', 'active');
`)

const claim = (uid, phone = '+967771234567') =>
  one(`select * from public.otp_claim_send($1, $2)`, [uid, phone])

console.log('=== الحاجزُ يبدأ مطفأً ===')
const s = await one(`select require_phone_verification r from public.app_settings where id = 1`)
ok('مفتاحُ الحاجز مطفأٌ في التنصيب', s.r === false,
   'ولو بدأ مشتعلاً لَحُبس كلُّ مستخدمٍ قائمٍ خارج التطبيق')

console.log('=== ولا رقمَ مؤكَّدٌ قبل التأكيد ===')
const before = await one(
  `select phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('يبدأ فارغاً', before.v === null)

console.log('=== الإرسالُ الأوّل يمرّ ===')
const first = await claim(A)
ok('مسموح', first.allowed === true, `السبب: ${first.reason}`)
const n1 = await one(`select count(*)::int c from public.phone_otp_sends`)
ok('وسُجّل أثرُه', n1.c === 1)

console.log('=== والثاني يُردّ بمهلةٍ ستّين ثانية ===')
const second = await claim(A)
ok('مردود', second.allowed === false && second.reason === 'cooldown')
ok('ويُقال كم يُنتظر', second.wait_seconds > 0 && second.wait_seconds <= 60,
   `${second.wait_seconds} ثانية`)
// **ولا يُسجَّل ما لم يُرسَل.** لو سُجّل المردودُ لَحُسب من حدّ الساعة،
// فمن ضغط ثلاثاً في ثانيةٍ استُنفد رصيدُه بلا رسالةٍ واحدة.
const n2 = await one(`select count(*)::int c from public.phone_otp_sends`)
ok('ولم يُسجَّل المردود', n2.c === 1)

console.log('=== وثلاثٌ في الساعة لا أكثر ===')
// يُزحف الأثرُ إلى ما قبل دقيقةٍ لتسقط المهلةُ وتبقى الساعة.
const age = (mins) => db.query(
  `update public.phone_otp_sends set created_at = created_at - ($1 || ' minutes')::interval
    where user_id = (select id from public.app_users where auth_user_id = $2)`,
  [String(mins), A])

await age(2)
const third = await claim(A)
ok('الثاني بعد المهلة يمرّ', third.allowed === true)
await age(2)
const fourth = await claim(A)
ok('والثالث يمرّ', fourth.allowed === true)
await age(2)
const fifth = await claim(A)
ok('والرابعُ يُردّ بحدّ الساعة', fifth.allowed === false && fifth.reason === 'hour_limit')

console.log('=== والحدُّ لصاحبه لا للناس ===')
// **وهذه هي التي تكشف الخطأ الشائع:** حدٌّ محسوبٌ على الجدول كلِّه يمنع
// مستخدماً لأنّ غيرَه أرسل.
const other = await claim(B)
ok('مستخدمٌ آخرُ لا يُمنع بحدّ غيره', other.allowed === true)

console.log('=== والإثباتُ يكتب الرقمَ ووقتَه ===')
const marked = await one(`select public.otp_mark_verified($1, $2) v`, [A, '+967771234567'])
ok('نجح الإثبات', marked.v === true)
const row = await one(
  `select phone, phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('الرقمُ هو ما أُكّد', row.phone === '+967771234567')
ok('والوقتُ مكتوب', row.v !== null)

console.log('=== ولا يُزحف تاريخُ التأكيد بنداءٍ ثانٍ ===')
const firstAt = row.v
await one(`select public.otp_mark_verified($1, $2) v`, [A, '+967779999999'])
const again = await one(
  `select phone, phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('التاريخُ كما هو', String(again.v) === String(firstAt))

console.log('=== ومن أكّد لا تُرسَل إليه رسالةٌ أخرى ===')
// رسالةٌ لمن أكّد مالٌ يُنفَق بلا سبب، و«مرّةً واحدة» هو القرار.
await age(120)
const afterVerified = await claim(A)
ok('مردود', afterVerified.allowed === false && afterVerified.reason === 'already_verified')

console.log('=== ومن لا ملفَّ له لا يُرسَل إليه ===')
const ghost = await claim('33333333-3333-3333-3333-333333333333')
ok('مردود', ghost.allowed === false && ghost.reason === 'no_profile')

console.log('=== ورقمٌ فارغٌ يُردّ ===')
const noPhone = await claim(B, '   ')
ok('مردود', noPhone.allowed === false && noPhone.reason === 'no_phone')

console.log('=== الصلاحيات: الدالّتان للخدمة وحدها ===')
// **وهذا أخطرُ ما في الملفّ.** `otp_mark_verified` ممنوحةً للمسجَّلين تجعل
// الحاجزَ زينةً: يؤكّد كلٌّ رقمَه — أو رقمَ غيره — بنداءٍ واحدٍ بلا رمز.
await db.exec(`set role authenticated`)
await mustFail('المسجَّلُ لا ينادي otp_mark_verified',
  () => db.query(`select public.otp_mark_verified($1, $2)`, [B, '+967770000001']))
await mustFail('ولا ينادي otp_claim_send',
  () => db.query(`select * from public.otp_claim_send($1, $2)`, [B, '+967770000001']))
await db.exec(`reset role`)

await db.exec(`set role anon`)
await mustFail('والزائرُ كذلك',
  () => db.query(`select public.otp_mark_verified($1, $2)`, [B, '+967770000002']))
await db.exec(`reset role`)

console.log('=== وعدّادُ الحدّ لا يُقرأ ولا يُصفَّر من التطبيق ===')
// لو قُرئ لَعُرف متى يُعاد الطلب، ولو كُتب لَصُفّر الحدُّ كلُّه.
await db.exec(`set role authenticated`)
const seen = await db.query(`select count(*)::int c from public.phone_otp_sends`)
ok('لا صفَّ يُرى', seen.rows[0].c === 0, 'الحرزُ مفعَّلٌ بلا سياسة')
await mustFail('ولا صفَّ يُحذف', async () => {
  const r = await db.query(`delete from public.phone_otp_sends returning id`)
  if (r.rows.length === 0) throw new Error('لم يُحذف شيء — الحرز يمنع')
})
await db.exec(`reset role`)

console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
