/**
 * حذف البيانات التجريبية.
 *
 * وأهمّ ما يُثبَت هنا ليس أن البذرة تُمحى — بل أن **الحقيقيّ ينجو**. فسكربتُ
 * تنظيفٍ يمحو كل شيء سهل، وقيمته كلّها في ما يتركه: عميلٌ سجّل نفسه أمس
 * وحجزه ودفعته يجب أن يبقوا، وسطرٌ واحدٌ خاطئ في ترتيب الحذف يمحوهم بلا صوت.
 *
 * فيُزرع هنا عميلٌ حقيقيّ **وسط** البذرة، ويُتحقّق منه بعدها هو وكل ما يتبعه.
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

// ── عميلٌ حقيقيّ وسط البذرة، له مزوّدٌ وحجزٌ ودفعة ─────────────────────────
const REAL = '99999999-9999-9999-9999-999999999999'
await db.exec(`
  insert into auth.users (id, email) values ('${REAL}', 'real@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email)
    values ('${REAL}', 'عميلٌ حقيقي', 'real@aras.ye');
`)
await db.exec(`
  -- حالة «موثَّق» تشترط تاريخ توثيق — قيدٌ في المخطط تحترمه بذرةُ الاختبار
  insert into public.service_providers
    (user_id, full_name, business_name, email, status, verified_at)
  select id, 'مزوّدٌ حقيقي', 'قاعة حقيقية', 'realprov@aras.ye', 'verified', now()
    from public.app_users where email = 'real@aras.ye';
`)
await db.exec(`
  insert into public.bookings
    (reference, user_id, provider_id, event_date, status, total_price, confirmed_at)
  select 'BK-REAL-0001', u.id, p.id, current_date + 30, 'confirmed', 500000, now()
    from public.app_users u, public.service_providers p
   where u.email = 'real@aras.ye' and p.email = 'realprov@aras.ye';
`)
await db.exec(`
  insert into public.payments
    (reference, booking_id, user_id, provider_id, amount, kind, status)
  select 'TRX-REAL-0001', b.id, b.user_id, b.provider_id, 150000, 'deposit', 'paid'
    from public.bookings b
    join public.app_users u on u.id = b.user_id
   where u.email = 'real@aras.ye';
`)

const before = {
  users: await count('app_users'),
  providers: await count('service_providers'),
  bookings: await count('bookings'),
  payments: await count('payments'),
}
console.log(`قبل: ${before.users} عميلاً، ${before.providers} مزوّداً، ` +
            `${before.bookings} حجزاً، ${before.payments} دفعة\n`)

// ── التشغيل ────────────────────────────────────────────────────────────────
await db.exec(read('clear_demo_data.sql'))

console.log('=== التجريبيّ زال ===')
check('لا عميل بلا حساب مصادقة', (await count('app_users', 'where auth_user_id is null')) === 0)
check('ولا مزوّد يتيم', (await count('service_providers', 'where user_id is null')) === 0)
check('والمقاييس اليومية فُرِّغت', (await count('daily_metrics')) === 0)
check('والإشعارات', (await count('push_notifications')) === 0)
check('والحملات', (await count('promotions')) === 0)
check('وإصدارات التطبيق', (await count('app_versions')) === 0)

console.log('\n=== والحقيقيّ نجا ===')
check('العميل الحقيقي باقٍ',
  (await count('app_users', `where email = 'real@aras.ye'`)) === 1)
check('ومزوّده باقٍ',
  (await count('service_providers', `where email = 'realprov@aras.ye'`)) === 1)
check('وحجزه باقٍ', (await count('bookings')) === 1, `${await count('bookings')} حجز`)
check('ودفعته باقية',
  (await count('payments', `where reference = 'TRX-REAL-0001'`)) === 1)

// ── وإعادةُ التشغيل؟ ────────────────────────────────────────────────────────
// لا `begin;` في السكربت — ومحرّر Supabase يُثبت كل جملةٍ وحدها. فإن انقطع
// التشغيل في منتصفه بقي نصفُ الحذف مُثبتاً، وأوّلُ ما يفعله المستخدم أن يعيد
// التشغيل. فتكرارُه يجب أن يمرّ بلا خطأ وألّا يمسّ ما نجا.
await db.exec(read('clear_demo_data.sql'))
check('التشغيل الثاني لا يخطئ ولا يمسّ الحقيقيّ',
  (await count('app_users')) === 1 && (await count('bookings')) === 1 &&
  (await count('payments')) === 1)

console.log('\n=== والمرجعُ لم يُمسّ ===')
const govs = await count('governorates')
const cats = await count('service_categories')
const plans = await count('subscription_plans')
check('المحافظات باقية', govs > 0, `${govs}`)
check('وأقسام الخدمات', cats > 0, `${cats}`)
check('وباقات الاشتراك', plans > 0, `${plans}`)
check('وسياسات الإلغاء', (await count('cancellation_policies')) > 0)

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 البذرة زالت، ومن سجّل نفسه بقي، والمرجع سليم.')
