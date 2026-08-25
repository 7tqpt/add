/**
 * مهامّ خطة العرس: قائمةٌ تُزرع مرّةً، وتُشطب، ولا يراها غيرُ صاحبها.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن القائمة **تُزرع مع الخطّة نفسها** — لا يُترك ذلك للتطبيق، وإلّا
 *      بقيت خططُ من دخل من نسخةٍ أقدم ورقةً بيضاء.
 *   ٢. **وأنها لا تُزرع مرّتين:** نداءٌ ثانٍ يُضاعف القائمة، ومن حذف مهمّةً
 *      يجدها عادت.
 *   ٣. وأن التقدّم **محسوبٌ من المشطوب** لا مكتوب.
 *   ٤. **وأن عميلاً لا يشطب مهمّةً في خطّة غيره** — وهذا الحارس في الدالّة
 *      لا في الشاشة.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create schema if not exists storage;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create table if not exists storage.buckets (
    id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  create or replace function storage.foldername(p text) returns text[]
    language sql immutable as $$ select string_to_array(p, '/') $$;
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql']) {
  await db.exec(read(f))
}
const file = read('plan_tasks.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: عميلان، لكلٍّ خطّة ────────────────────────────────────────────────
const aUid = '10000000-0000-0000-0000-000000000001'
const bUid = '10000000-0000-0000-0000-000000000002'
await db.exec(`
  insert into auth.users (id, email) values
    ('${aUid}', 'a@sdd.company'), ('${bUid}', 'b@sdd.company')
  on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status) values
    ('${aUid}', 'أمّ العروس', 'a@sdd.company', 'active'),
    ('${bUid}', 'جارتها',    'b@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = excluded.auth_user_id;`)

const mine = await one(`
  insert into public.wedding_plans (user_id, wedding_date, governorate, guests_count, budget)
       values ((select id from public.app_users where email = 'a@sdd.company'),
               current_date + 45, 'صنعاء', 250, 25000000)
  returning *`)
const hers = await one(`
  insert into public.wedding_plans (user_id, wedding_date, governorate, guests_count, budget)
       values ((select id from public.app_users where email = 'b@sdd.company'),
               current_date + 90, 'تعز', 120, 9000000)
  returning *`)

// ── ١. القائمة تُزرع مع الخطّة ───────────────────────────────────────────────
const seeded = Number((await one(
  `select count(*) as ع from public.plan_tasks where plan_id = $1`, [mine.id])).ع)
ok('إنشاءُ الخطّة يزرع قائمةً غير فارغة', seeded > 0)
ok('وكلُّها غيرُ منجزة في أوّلها',
   Number((await one(`select count(*) as ع from public.plan_tasks
                       where plan_id = $1 and is_done`, [mine.id])).ع) === 0)
ok('والترتيب مثبّتٌ لا عشوائيّ',
   (await rows(`select sort_order from public.plan_tasks
                 where plan_id = $1 order by sort_order limit 2`, [mine.id]))
     .every((r, i, a) => i === 0 || r.sort_order > a[i - 1].sort_order))

// ── ٢. ولا تُزرع مرّتين ──────────────────────────────────────────────────────
//
// **وهذا ما ينكسر بصمت:** حذفَ المستخدمُ مهمّةً لا يريدها، ثم فُتحت الشاشة
// فعادت — أو تضاعفت القائمة كلُّها فصارت أربعين مهمّةً مكرّرة.
await db.query(`delete from public.plan_tasks
                 where id = (select id from public.plan_tasks
                              where plan_id = $1 order by sort_order limit 1)`, [mine.id])
const afterDelete = Number((await one(
  `select count(*) as ع from public.plan_tasks where plan_id = $1`, [mine.id])).ع)
await db.query(`select public.seed_plan_tasks($1)`, [mine.id])
ok('نداءٌ ثانٍ للزرع لا يُضيف شيئاً ولا يُعيد المحذوف',
   Number((await one(`select count(*) as ع from public.plan_tasks
                       where plan_id = $1`, [mine.id])).ع) === afterDelete)

// ── ٣. الشطب والتقدّم ───────────────────────────────────────────────────────
const asA = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${aUid}', false)`)
  await db.exec(`set role authenticated`)
}
const asB = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${bUid}', false)`)
  await db.exec(`set role authenticated`)
}

const before = await one(
  `select * from public.v_plan_progress where plan_id = $1`, [mine.id])
ok('التقدّم صفرٌ قبل أن يُشطب شيء', Number(before.tasks_percent) === 0)
ok('والمتبقّي = الكلّ', Number(before.tasks_left) === Number(before.tasks_total))

const first = await one(
  `select id from public.plan_tasks where plan_id = $1 order by sort_order limit 1`,
  [mine.id])
await asA()
const toggled = await one(`select * from public.api_toggle_plan_task($1)`, [first.id])
ok('الشطب يقلب الحالة', toggled.is_done === true)
ok('ويختم الوقت — «أُنجزت» بلا وقتٍ لا تُراجَع', toggled.done_at !== null)

const mid = await one(
  `select * from public.v_plan_progress where plan_id = $1`, [mine.id])
await db.exec(`reset role`)
ok('والتقدّم محسوبٌ من المشطوب لا مكتوب',
   Number(mid.tasks_done) === 1 &&
   Number(mid.tasks_percent) === Math.round(100 / Number(mid.tasks_total)))

await asA()
const back = await one(`select * from public.api_toggle_plan_task($1)`, [first.id])
ok('وإلغاءُ الشطب يمسح الوقت معه', back.is_done === false && back.done_at === null)

// ── ٤. ومهمّةٌ تُضاف في آخر القائمة ─────────────────────────────────────────
const added = await one(
  `select * from public.api_add_plan_task($1, '  استئجار كراسي إضافية  ')`, [mine.id])
ok('المضافةُ تُشذَّب من الفراغ', added.title === 'استئجار كراسي إضافية')
ok('وتقع في آخر القائمة',
   Number(added.sort_order) > Number((await one(
     `select max(sort_order) as م from public.plan_tasks
       where plan_id = $1 and id <> $2`, [mine.id, added.id])).م))

let raised = null
try {
  await db.query(`select public.api_add_plan_task($1, '   ')`, [mine.id])
} catch (e) { raised = e.message }
ok('ومهمّةٌ فارغة تُردّ', /اكتب المهمّة/.test(raised ?? ''))

// ── ٥. وخطّةُ غيرك مغلقة ────────────────────────────────────────────────────
//
// الحارسُ في الدالّة لا في الشاشة: أيُّ حاملِ جلسةٍ ينادي `rpc` مباشرةً.
await asB()
raised = null
try {
  await db.query(`select public.api_toggle_plan_task($1)`, [first.id])
} catch (e) { raised = e.message }
ok('عميلٌ آخر لا يشطب مهمّةً في خطّتك', /غير موجودة/.test(raised ?? ''))

raised = null
try {
  await db.query(`select public.api_add_plan_task($1, 'مهمّةٌ دسّها غريب')`, [mine.id])
} catch (e) { raised = e.message }
ok('ولا يُضيف فيها', /غير موجودة/.test(raised ?? ''))

ok('وحذفُه لا يقع', (await one(
  `select public.api_delete_plan_task($1) as م`, [first.id])).م === false)

// وما زالت المهمّة في مكانها — الردُّ ليس صمتاً عن حذفٍ وقع.
await db.exec(`reset role`)
ok('والمهمّة باقيةٌ بعد محاولته',
   Number((await one(`select count(*) as ع from public.plan_tasks
                       where id = $1`, [first.id])).ع) === 1)

// ── ٦. وسياسةُ الصفوف تُخفي مهامَّ غيرك عن القراءة ──────────────────────────
await asB()
const seen = Number((await one(
  `select count(*) as ع from public.plan_tasks where plan_id = $1`, [mine.id])).ع)
ok('ولا يقرأ صفّاً منها أصلاً', seen === 0)
ok('ويقرأ مهامَّ خطّته هو',
   Number((await one(`select count(*) as ع from public.plan_tasks
                       where plan_id = $1`, [hers.id])).ع) > 0)
await db.exec(`reset role`)

// ── ٧. والقيدُ يمنع الكذب الصامت ────────────────────────────────────────────
raised = null
try {
  await db.query(`update public.plan_tasks set is_done = true where id = $1`, [first.id])
} catch (e) { raised = e.message }
ok('«منجَزة» بلا وقتٍ يرفضها القيد', /plan_task_done_time/.test(raised ?? ''))

// ── ٨. وحذفُ الخطّة يأخذ مهامَّها معها ──────────────────────────────────────
await db.query(`delete from public.wedding_plans where id = $1`, [hers.id])
ok('لا مهمّةٌ يتيمةٌ بعد حذف خطّتها',
   Number((await one(`select count(*) as ع from public.plan_tasks
                       where plan_id = $1`, [hers.id])).ع) === 0)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات plan_tasks.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
