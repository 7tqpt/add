/**
 * حذف أقسام الخدمات.
 *
 * القسم مربوطٌ بـ `on delete restrict` من `provider_services` — أي أن القاعدة
 * ترفض حذفه ما دامت تحته خدمة. فيُثبَت هنا شيئان: أن السكربت يمرّ رغم ذلك
 * (لأنه يحذف الخدمات أوّلاً)، وأن الحجز القديم **ينجو** بدل أن يسقط مع قسمه —
 * فتاريخ ما جرى لا يُمحى بحذف مرجعٍ يُعاد بناؤه.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql']) {
  await db.exec(read(f))
}

const one = async (sql) => Number((await db.query(sql)).rows[0].n)
const count = (t, where = '') => one(`select count(*)::int as n from public.${t} ${where}`)

let fail = 0
const check = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

// ── حجزٌ يحمل قسماً: ما يجب أن ينجو ────────────────────────────────────────
const REAL = '99999999-9999-9999-9999-999999999999'
await db.exec(`
  insert into auth.users (id, email) values ('${REAL}', 'real@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email)
    values ('${REAL}', 'عميلٌ حقيقي', 'real@aras.ye');
  insert into public.service_providers
    (user_id, full_name, business_name, email, status, verified_at)
  select id, 'مزوّدٌ حقيقي', 'قاعة حقيقية', 'realprov@aras.ye', 'verified', now()
    from public.app_users where email = 'real@aras.ye';
  insert into public.provider_services (provider_id, category_id, title, price)
  select p.id, c.id, 'خدمةٌ حقيقية', 100000
    from public.service_providers p, public.service_categories c
   where p.email = 'realprov@aras.ye' and c.slug = 'halls';
  insert into public.bookings
    (reference, user_id, provider_id, category_id, category_name,
     event_date, status, total_price, confirmed_at)
  select 'BK-REAL-0001', u.id, p.id, c.id, c.name,
         current_date + 30, 'confirmed', 500000, now()
    from public.app_users u, public.service_providers p, public.service_categories c
   where u.email = 'real@aras.ye' and p.email = 'realprov@aras.ye' and c.slug = 'halls';
`)

const cats = await count('service_categories')
const bookingsBefore = await count('bookings')
console.log(`قبل: ${cats} قسماً، ${await count('provider_services')} خدمة، ` +
            `${bookingsBefore} حجزاً\n`)

// ── الرفض المتوقّع: القسم لا يُحذف وحده ───────────────────────────────────
// إن سقط هذا يوماً فقد تغيّر المخطط من `restrict` إلى `cascade`، وحينها
// يصير ترتيبُ السكربت زينةً لا ضرورة — والاختبار هو من يخبرنا.
let restricted = false
try {
  await db.exec(`delete from public.service_categories where slug = 'halls';`)
} catch (e) {
  restricted = /foreign key|violates/i.test(e.message)
}
check('القاعدة ترفض حذف قسمٍ تحته خدمة (restrict)', restricted)

// ── التشغيل ────────────────────────────────────────────────────────────────
await db.exec(read('clear_categories.sql'))

console.log('\n=== الأقسام زالت ===')
check('لا أقسام', (await count('service_categories')) === 0)
check('ولا خدمات معروضة', (await count('provider_services')) === 0)
check('ولا ارتباطات', (await count('provider_categories')) === 0)

console.log('\n=== وما لا يتبع القسم نجا ===')
const REF = `where reference = 'BK-REAL-0001'`
check('الحجز باقٍ', (await count('bookings', REF)) === 1)
check('وقسمه صار فارغاً لا محذوفاً معه',
  (await count('bookings', `${REF} and category_id is null`)) === 1)
check('واسم القسم محفوظٌ نصّاً في الحجز',
  (await count('bookings', `${REF} and category_name <> ''`)) === 1)
check('ولا حجز سقط مع الأقسام', (await count('bookings')) === bookingsBefore,
  `${await count('bookings')} من ${bookingsBefore}`)
check('والمزوّد باقٍ', (await count('service_providers', `where email = 'realprov@aras.ye'`)) === 1)
check('والعميل باقٍ', (await count('app_users', `where email = 'real@aras.ye'`)) === 1)
check('والمحافظات', (await count('governorates')) > 0)
check('والباقات', (await count('subscription_plans')) > 0)

// ── وإعادة التشغيل ─────────────────────────────────────────────────────────
// لا `begin;` — ومحرّر Supabase يُثبت كل جملةٍ وحدها، فقد ينقطع في منتصفه.
await db.exec(read('clear_categories.sql'))
check('التشغيل الثاني لا يخطئ',
  (await count('service_categories')) === 0 &&
  (await count('bookings', REF)) === 1)


// ── والاستعادة ─────────────────────────────────────────────────────────────
// اللوحة تُفعّل القسم وتُعطّله ولا تُنشئه، فلا طريق في الواجهة لإعادة ما
// أُفرغ. فيُختبر رفيقُ السكربت هنا: هل يعيد الاثني عشر بحقولها؟
await db.exec(read('restore_categories.sql'))
console.log('\n=== والاستعادة تُرجعها ===')
check('عادت الأقسام الاثنا عشر', (await count('service_categories')) === 12,
  `${await count('service_categories')}`)
check('ومعها الحقول الخاصة بالقسم',
  (await one(`select count(*)::int as n from public.service_categories
               where jsonb_array_length(custom_fields) > 0`)) === 12)
check('و«القاعات والخيام» فيها حقل السعة',
  (await one(`select count(*)::int as n from public.service_categories
               where slug = 'halls' and custom_fields @> '[{"key":"capacity"}]'::jsonb`)) === 1)

await db.exec(read('restore_categories.sql'))
check('واستعادةٌ ثانية لا تُكرّر ولا تُخطئ', (await count('service_categories')) === 12,
  `${await count('service_categories')}`)

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 الأقسام زالت، والحجز نجا، والاستعادة تُرجعها.')
