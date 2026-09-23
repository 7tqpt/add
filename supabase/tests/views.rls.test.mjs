// طريقة عرض بلا security_invoker تعمل بصلاحيات مالكها فتلتفّ حول RLS.
// هذا الفحص يثبت أن العميل لا يرى عبر v_admin_* ما تمنعه السياسات.
//
// ── واستُثنيت واحدةٌ، ومعها ما يقوم مقامَ القاعدة ──────────────────────────
//
// `v_admin_providers` صارت `security definer` عمداً في `provider_columns.sql`:
// بعد نزع أعمدة البريد والجوّال والأرباح عن `authenticated`، طريقةٌ تتبع
// صلاحيةَ سائلها تخرج للمسؤول نفسِه بأعمدةٍ فارغة. فحرزُها شرطٌ في نصّها —
// `where public.is_admin()` — لا صلاحيةُ من ناداها.
//
// **والاستثناءُ لا يُؤخذ على الكلمة**: الشرطُ يُقاس بنداءٍ من مجهولٍ ومن
// مسجَّلٍ ليس مسؤولاً — ويجب أن يخرج الاثنان بصفر. وهو قياسٌ أوثقُ من سؤال
// `pg_class` عن رايةٍ: تلك تقول «كُتبت»، وهذا يقول «تمنع».
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'provider_columns.sql']) {
  await db.exec(read(f))
}

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}

// ── ١. كلُّ طرق اللوحة تتبع سائلَها، إلّا المستثناةَ بحارسها ────────────────
const invoker = ['v_admin_services', 'v_admin_settlements', 'v_admin_reviews',
                 'v_admin_subscription_plans', 'v_admin_promotions', 'v_plan_summary']

const bad = await db.query(`
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname='public' and c.relkind='v' and c.relname = any($1)
     and coalesce((select option_value from pg_options_to_table(c.reloptions)
                    where option_name='security_invoker'), 'false') <> 'true'`, [invoker])
ok(`كل طرق العرض تعمل بصلاحيات المستدعي${bad.rows.length ? `: ${bad.rows.map(r => r.relname).join(', ')}` : ''}`,
   bad.rows.length === 0)

await db.exec(`set role anon`)
const leaked = await db.query('select count(*)::int as n from public.v_admin_settlements')
await db.exec('reset role')
ok(`المجهول لا يرى مستحقات الشركاء عبر طريقة العرض (رأى ${leaked.rows[0].n})`,
   leaked.rows[0].n === 0)

// ── ٢. و`v_admin_providers` تُقاس بما تمنع لا برايةٍ فيها ───────────────────
//
// وهي الطريقةُ الوحيدةُ التي تخرج ببريد المزوّد وجوّاله وأرباحه — فلو خرجت
// لغير مسؤولٍ لَكان نزعُ الأعمدة كلُّه زينةً تُلتفّ من هنا.
const total = (await db.query(
  'select count(*)::int as n from public.service_providers')).rows[0].n
ok(`في القاعدة مزوّدون يُقاس عليهم (${total})`, total > 0)

const seen = async (label, uid) => {
  await db.exec(`select set_config('test.uid', ${uid ? `'${uid}'` : "''"}, false)`)
  await db.exec(`set role ${uid ? 'authenticated' : 'anon'}`)
  const n = (await db.query(
    'select count(*)::int as n from public.v_admin_providers')).rows[0].n
  await db.exec('reset role')
  return n
}

ok(`المجهول لا يرى مزوّداً واحداً عبر v_admin_providers (رأى ${await seen('anon', null)})`,
   (await seen('anon', null)) === 0)

// مسجَّلٌ ليس مسؤولاً — وهو الحالةُ الأكثر: كلُّ عميلٍ في التطبيق.
const customer = '99999999-9999-9999-9999-999999999999'
await db.exec(`
  insert into auth.users (id, email) values ('${customer}', 'c@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${customer}', 'عميل', 'c@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${customer}';`)
const byCustomer = await seen('customer', customer)
ok(`العميلُ المسجَّل لا يرى مزوّداً عبر v_admin_providers (رأى ${byCustomer})`, byCustomer === 0)

// والمسؤولُ يرى — وإلّا كان الحارسُ قفلاً على الجميع لا حرزاً.
const admin = '88888888-8888-8888-8888-888888888888'
await db.exec(`
  insert into auth.users (id, email) values ('${admin}', 'a@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${admin}', 'a@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)
const byAdmin = await seen('admin', admin)
ok(`والمسؤولُ يرى المزوّدين كلَّهم (${byAdmin} من ${total})`, byAdmin === total)

await db.close()

// ── ٣. وقاعدةٌ أُعيد عليها `apply.sql` وحدَه ────────────────────────────────
//
// **وهذه هي الحالةُ التي تُنسى.** الحارسُ مكتوبٌ في ملفّين: `apply.sql`
// و`provider_columns.sql`. ومن شغّل الثاني ثمّ أعاد الأوّلَ ليحدّث طرقَ
// اللوحة **أعاد الطريقةَ كما كتبها الأوّل** — فلو صُحّح أحدُهما وحدَه لَعادت
// الثغرةُ بيدِ من ظنّ أنّه يحدّث.
//
// ولا تُقاس هذه في القاعدة أعلاه: هناك يُشغَّل `provider_columns.sql` بعده
// فيستره. فتُبنى قاعدةٌ ثانيةٌ بلا الملفّ الثاني أصلاً.
const plain = new PGlite()
await plain.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql']) {
  await plain.exec(read(f))
}

const plainTotal = (await plain.query(
  'select count(*)::int as n from public.service_providers')).rows[0].n
await plain.exec(`select set_config('test.uid', '', false); set role anon;`)
const plainSeen = (await plain.query(
  'select count(*)::int as n from public.v_admin_providers')).rows[0].n
await plain.exec('reset role')
ok(`و**apply.sql وحدَه** لا يُخرج مزوّداً للمجهول (رأى ${plainSeen} من ${plainTotal})`,
   plainTotal > 0 && plainSeen === 0)
await plain.close()

// فحص تسريب يخرج بصفر عند التسريب لا يفحص شيئاً — كان يطبع ❌ ويُعدّ ناجحاً.
process.exit(fail === 0 ? 0 : 1)
