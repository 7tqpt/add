/**
 * apply.sql — لصقة واحدة تُشغَّل بعد install.sql.
 *
 * يتحقّق من ثلاثة أمور لا يكشفها قراءة الملف:
 *   ١. أنه يعمل فوق install.sql + seed.sql ويعيد صفوفاً فعلية من كل طريقة عرض.
 *   ٢. أن تشغيله مرتين لا يغيّر شيئاً (لا فجوات في الترتيب، لا تكرار).
 *   ٣. أنه ينجح بعد إضافة عمود إلى جدول أصلي — وهي الحالة التي تنكسر فيها
 *      `create or replace view` بالضبط، والسبب في اختيار drop-then-create.
 */
import { PGlite } from '@electric-sql/pglite'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'

const dir = fileURLToPath(new URL('..', import.meta.url))
const read = (name) => readFile(dir + name, 'utf8')

const VIEWS = [
  'v_admin_providers',
  'v_admin_services',
  'v_admin_settlements',
  'v_admin_reviews',
  'v_admin_subscription_plans',
  'v_admin_promotions',
  'v_plan_summary',
]

const db = new PGlite()

// PGlite لا يحمل مخطط auth الذي تعتمد عليه سياسات Supabase، فيُصنع هنا.
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon;
  create role authenticated;
`)

await db.exec(await read('install.sql'))
await db.exec(await read('seed.sql'))
console.log('✓ install.sql + seed.sql')

const apply = await read('apply.sql')

// ١ — أول تشغيل
await db.exec(apply)

/**
 * كل طريقة عرض تُقابَل بجدولها الأصلي، لا بالصفر.
 *
 * `count > 0` كان الاختبار الأول، وسقط مرة من كل ثماني تشغيلات: seed.sql يولّد
 * التقييمات من `abs(hashtext(uuid))`، فعددها يتراوح بين ٤ و ٢٠ وقد يبلغ الصفر.
 * والمقارنة بالجدول أقوى لا أضعف: تكشف الصفوف المضروبة من join سيّئ (fan-out)
 * والصفوف الضائعة من inner join مكان left join — وكلاهما يمرّ من «أكبر من صفر».
 */
const BASE = {
  v_admin_providers: 'service_providers',
  v_admin_services: 'provider_services',
  v_admin_settlements: 'settlements',
  v_admin_reviews: 'reviews',
  v_admin_subscription_plans: 'subscription_plans',
  v_admin_promotions: 'promotions',
  v_plan_summary: 'wedding_plans',
}
for (const [view, table] of Object.entries(BASE)) {
  const { rows } = await db.query(
    `select (select count(*) from public.${view})::int as v,
            (select count(*) from public.${table})::int as t`,
  )
  const { v, t } = rows[0]
  assert.equal(v, t, `${view} ترجع ${v} صفاً و ${table} فيه ${t} — الجمع يضاعف أو يُسقط`)
}
console.log(`✓ ${VIEWS.length} طرق عرض تطابق جداولها صفاً بصف`)

// كل طريقة عرض تُنفَّذ بصلاحيات المستدعي، وإلا التفّت حول RLS.
const { rows: invoker } = await db.query(`
  select c.relname from pg_class c
   where c.relkind = 'v' and c.relname = any($1)
     and coalesce(c.reloptions::text, '') not like '%security_invoker=true%'`, [VIEWS])
assert.equal(invoker.length, 0, `طرق بلا security_invoker: ${invoker.map((r) => r.relname)}`)
console.log('✓ security_invoker مفعّل في كلٍّ منها')

// الأعمدة التي تُضاف فوق الجداول هي سبب وجود الملف أصلاً.
const added = {
  v_admin_providers: 'categories',
  v_admin_services: 'category_name',
  v_admin_settlements: 'bookings_count',
  v_admin_reviews: 'provider_name',
  v_admin_subscription_plans: 'subscribers_count',
  v_admin_promotions: 'category_name',
  v_plan_summary: 'user_name',
}
for (const [view, column] of Object.entries(added)) {
  const { rows } = await db.query(
    `select 1 from information_schema.columns
      where table_schema = 'public' and table_name = $1 and column_name = $2`,
    [view, column],
  )
  assert.equal(rows.length, 1, `${view}.${column} مفقود`)
}
console.log('✓ الأعمدة المضافة موجودة')

// ٢ — تشغيل ثانٍ: يجب ألا يتغيّر شيء
const snapshot = async () =>
  (await db.query('select slug, sort_order from public.service_categories order by slug')).rows
const before = await snapshot()
await db.exec(apply)
assert.deepEqual(await snapshot(), before, 'التشغيل الثاني غيّر ترتيب الأقسام')

const order = (await db.query('select sort_order from public.service_categories order by sort_order'))
  .rows.map((r) => r.sort_order)
assert.deepEqual(order, [...Array(order.length).keys()].map((i) => i + 1), `فجوات في الترتيب: ${order}`)

const catering = (await db.query(
  `select sort_order from public.service_categories where slug = 'catering'`)).rows
assert.equal(catering.length, 1, 'قسم الطبخ مكرّر أو مفقود')
assert.equal(catering[0].sort_order, 2, 'الطبخ ليس في الترتيب الثاني')
console.log(`✓ التشغيل مرتين لا يغيّر شيئاً — ${order.length} قسماً بلا فجوات، الطبخ ثانياً`)

// ٣ — عمود جديد على جدول أصلي، ثم إعادة التشغيل.
//     `create or replace view` تفشل هنا بـ «cannot change name of view column»
//     لأن ‎p.*‎ تُدرج العمود الجديد قبل الأعمدة المحسوبة. drop-then-create تنجح.
await db.exec(`alter table public.service_providers add column whatsapp text`)
await db.exec(apply)
const { rows: hasNew } = await db.query(
  `select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'v_admin_providers' and column_name = 'whatsapp'`)
assert.equal(hasNew.length, 1, 'الطريقة لم تلتقط العمود الجديد')
console.log('✓ يعيد التشغيل بنجاح بعد إضافة عمود للمخطط')

await db.close()
console.log('\nكل اختبارات apply.sql نجحت.')
