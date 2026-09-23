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

console.log('=== ولا يُزحف التاريخُ بتأكيدِ الرقم نفسِه ===')
const firstAt = row.v
await one(`select public.otp_mark_verified($1, $2) v`, [A, '+967771234567'])
const again = await one(`select phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('التاريخُ كما هو', String(again.v) === String(firstAt))

console.log('=== وتبديلُ الرقم يُبطل تأكيدَه ===')
// **وهي ثغرةٌ تُفرِغ الحاجزَ من معناه:** من أكّد رقماً يملكه ثمّ بدّله بقي
// «مؤكَّداً» على رقمٍ لم يشهد له أحد. والمنعُ في القاعدة لا في الشاشة —
// `api_update_profile` تُنادى بلا شاشةٍ أصلاً.
await db.query(
  `update public.app_users set phone = $2 where auth_user_id = $1`,
  [A, '+967770000009'])
const afterEdit = await one(
  `select phone, phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('الرقمُ تبدّل', afterEdit.phone === '+967770000009')
ok('**والتأكيدُ بُطل**', afterEdit.v === null,
   'وبلا هذا تشهد الرايةُ لرقمٍ لم يُؤكَّد')

console.log('=== ولا يُبطَل بحفظِ الرقم نفسِه ===')
// من فتح «تعديل الملف» ليبدّل اسمَه أو صورتَه لا يُعاد إلى الحاجز.
await one(`select public.otp_mark_verified($1, $2) v`, [A, '+967770000009'])
const before2 = await one(
  `select phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
await db.query(
  `update public.app_users set phone = $2, full_name = 'أيمن الحرازي'
    where auth_user_id = $1`, [A, '+967770000009'])
const same = await one(
  `select phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('التأكيدُ باقٍ', same.v !== null && String(same.v) === String(before2.v))

console.log('=== والرقمُ الجديدُ تأكيدُه جديد ===')
// وكانت `coalesce` تُبقي تاريخَ الأوّل، فيُقرأ أنّ هذا الرقمَ مؤكَّدٌ منذ
// حينٍ وهو لم يُؤكَّد إلّا الآن.
await db.query(
  `update public.app_users set phone_verified_at = now() - interval '10 days'
    where auth_user_id = $1`, [A])
const oldStamp = await one(
  `select phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
await one(`select public.otp_mark_verified($1, $2) v`, [A, '+967770000011'])
const fresh = await one(
  `select phone, phone_verified_at v from public.app_users where auth_user_id = $1`, [A])
ok('الرقمُ هو الجديد', fresh.phone === '+967770000011')
ok('والتاريخُ جُدّد', new Date(fresh.v) > new Date(oldStamp.v))

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

// ── حدُّ المحاولات — الثغرةُ التي كشفها الفحصُ الأمنيّ ──────────────────────
//
// كان الإرسالُ محدوداً والتحقّقُ مفتوحاً. والمسار: يفتح المهاجمُ حساباً،
// ينادي `send` **برقم الضحيّة** فتصلها رسالة، ثمّ يخمّن الرمزَ بلا عدد.
// وإن أصاب، صار رقمُ الضحيّة مؤكَّداً على حسابه هو.
console.log('\n=== وحدُّ المحاولات: خمسٌ في ربع ساعة ===')

const C = '44444444-4444-4444-4444-444444444444'
const D = '55555555-5555-5555-5555-555555555555'
await db.exec(`
  insert into auth.users (id, email) values
    ('${C}', 'hani@aras.ye'), ('${D}', 'salem@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email, phone, status) values
    ('${C}', 'هاني', 'hani@aras.ye', '772222222', 'active'),
    ('${D}', 'سالم', 'salem@aras.ye', '773333333', 'active');
`)

const tryOtp = (uid, phone) =>
  one(`select * from public.otp_claim_verify($1, $2)`, [uid, phone])

const victim = '+967777654321'
const results = []
for (let i = 0; i < 6; i++) results.push(await tryOtp(C, victim))

ok('الخمسُ الأُوَل تمرّ', results.slice(0, 5).every((r) => r.allowed === true),
   results.slice(0, 5).map((r) => r.reason).join('/'))
ok('**والسادسةُ تُردّ**', results[5].allowed === false && results[5].reason === 'attempt_limit',
   `السبب: ${results[5].reason}`)
ok('ويُقال كم يُنتظر', results[5].wait_seconds > 0 && results[5].wait_seconds <= 900,
   `${results[5].wait_seconds} ثانية`)

// **ولا تُسجَّل المردودةُ**، وإلّا امتدّ الحبسُ بكلّ نقرةٍ يائسة.
const attempts = await one(
  `select count(*)::int c from public.phone_otp_attempts where phone = $1`, [victim])
ok('ولم تُسجَّل المردودة', attempts.c === 5, `المسجَّل: ${attempts.c}`)

console.log('=== والحدُّ على الرقم لا على الحساب وحدَه ===')
// **وهذه هي التي تُغلق الثغرةَ فعلاً.** حدٌّ على المستخدم وحدَه يُلتفّ عليه
// بحساباتٍ تُفتح في دقيقة: عشرةُ حسابات = خمسون محاولةً على الرقم نفسِه.
const byOther = await tryOtp(D, victim)
ok('**حسابٌ آخرُ لا يُكمل على الرقم نفسِه**', byOther.allowed === false,
   `السبب: ${byOther.reason}`)

console.log('=== ورقمٌ آخرُ من الحساب نفسِه يمرّ ما لم يُستنفد حدُّه ===')
const otherPhone = await tryOtp(D, '+967777111222')
ok('يمرّ', otherPhone.allowed === true, `السبب: ${otherPhone.reason}`)

console.log('=== وبعد ربع ساعةٍ يُفتح البابُ من جديد ===')
await db.query(
  `update public.phone_otp_attempts set created_at = created_at - interval '16 minutes'`)
const later = await tryOtp(C, victim)
ok('يمرّ بعد انقضاء النافذة', later.allowed === true, `السبب: ${later.reason}`)

console.log('=== وعشرون في اليوم سقفٌ لا يُتجاوز ===')
await db.exec(`delete from public.phone_otp_attempts`)
await db.query(`
  insert into public.phone_otp_attempts (user_id, phone, created_at)
  select (select id from public.app_users where auth_user_id = $1), $2,
         now() - interval '2 hours'
    from generate_series(1, 20)`, [C, victim])
const dayCapped = await tryOtp(C, victim)
ok('**مردودٌ بحدّ اليوم**', dayCapped.allowed === false && dayCapped.reason === 'attempt_day_limit',
   `السبب: ${dayCapped.reason}`)

console.log('=== والمحاولاتُ تُمحى عند النجاح ===')
// وإلّا بقي من أكّد محسوباً عليه عشرون محاولةً ليومٍ كامل — فلو بدّل رقمه
// في اليوم نفسِه (والتبديلُ يُبطل التأكيد) وجد البابَ مغلقاً بمحاولاتٍ نجحت.
await one(`select public.otp_clear_attempts($1, $2)`, [C, victim])
const cleared = await one(`select count(*)::int c from public.phone_otp_attempts`)
ok('لم يبقَ أثر', cleared.c === 0, `الباقي: ${cleared.c}`)
const afterClear = await tryOtp(C, victim)
ok('والبابُ مفتوح', afterClear.allowed === true)

console.log('=== ومن لا ملفَّ له لا يحاول ===')
const ghostTry = await tryOtp('66666666-6666-6666-6666-666666666666', victim)
ok('مردود', ghostTry.allowed === false && ghostTry.reason === 'no_profile')

console.log('=== والدالّتان للخدمة وحدها ===')
// **ولو مُنحت `otp_clear_attempts` للمسجَّلين لَصُفِّر الحدُّ بنداءٍ بين كلّ
// تخمينين** — فيصير الحدُّ زينةً كاملة.
await db.exec(`set role authenticated`)
await mustFail('المسجَّلُ لا ينادي otp_claim_verify',
  () => db.query(`select * from public.otp_claim_verify($1, $2)`, [C, victim]))
await mustFail('**ولا ينادي otp_clear_attempts**',
  () => db.query(`select public.otp_clear_attempts($1, $2)`, [C, victim]))
await db.exec(`reset role`)

await db.exec(`set role anon`)
await mustFail('والزائرُ كذلك', () =>
  db.query(`select * from public.otp_claim_verify($1, $2)`, [C, victim]))
await db.exec(`reset role`)

console.log('=== وعدّادُ المحاولات لا يُقرأ ولا يُصفَّر من التطبيق ===')
await db.exec(`set role authenticated`)
const seenAttempts = await db.query(`select count(*)::int c from public.phone_otp_attempts`)
ok('لا صفَّ يُرى', seenAttempts.rows[0].c === 0, 'الحرزُ مفعَّلٌ بلا سياسة')
await mustFail('ولا صفَّ يُحذف', async () => {
  const r = await db.query(`delete from public.phone_otp_attempts returning id`)
  if (r.rows.length === 0) throw new Error('لم يُحذف شيء — الحرز يمنع')
})
await db.exec(`reset role`)

console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
