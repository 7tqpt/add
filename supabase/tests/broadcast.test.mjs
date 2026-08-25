/**
 * الحملات: من صفٍّ في اللوحة إلى صناديق الناس.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن الإرسال **يُنتج صفوفاً فعلاً** — وهذا هو العطب الذي كان: الحملة
 *      تُكتب وتُعرض «مُرسل» ولا يصل أحداً شيء.
 *   ٢. أن الجمهور يُحترم: «مقدّمو الخدمة» لا تصل عملاءَ، و«العملاء» لا تصل
 *      مقدّمي خدمة.
 *   ٣. أن الموقوف لا يصله شيء.
 *   ٤. **وأن الحملة لا تُرسَل مرّتين** — ضغطتان على الزرّ تعنيان إشعارين على
 *      جوال كل مستخدم بالنصّ نفسه.
 *   ٥. وأن من لا صلاحية له لا يُرسل.
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
                 'invitations.sql', 'notifications.sql']) {
  await db.exec(read(f))
}
const file = read('broadcast.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مسؤولٌ مالك، وموقوفٌ واحد ─────────────────────────────────────────
const auid = '33333333-3333-3333-3333-333333333333'
await db.exec(`
  insert into auth.users (id, email) values ('${auid}', 'a@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)

// **بيانات العرض لا تربط مقدّمي الخدمة بحساباتهم:** ٤٤ مزوّداً كلُّهم
// `user_id = null`. فاختبارٌ يُرسل إلى «مقدّمي الخدمة» عليها كما هي يقيس صفراً
// ويمرّ وهو لا يقيس شيئاً — ولذلك يوجد التأكيدُ الثالث أدناه. فيُربط اثنان.
await db.exec(`
  update public.service_providers p set user_id = u.id
    from (select id, row_number() over (order by id) as n
            from public.app_users where status = 'active') u
   where u.n <= 2
     and p.id = (select id from public.service_providers
                  where user_id is null order by id limit 1 offset u.n - 1)`)

// مستخدمٌ ليس مقدّم خدمة — يُوقَف، فلا تصله حملةٌ للجميع. وبيانات العرض فيها
// موقوفون أصلاً، فيُقاس الفرق قبلَ وبعد لا بمقارنة العدد بحجم الجدول.
const before = Number((await one(
  `select count(*) as ع from public.broadcast_audience('all')`)).ع)
const banned = await one(`
  update public.app_users set status = 'suspended'
   where id = (select u.id from public.app_users u
                where u.status <> 'suspended'
                  and not exists (select 1 from public.service_providers p
                                   where p.user_id = u.id)
                limit 1)
  returning id`)

const counts = await one(`
  select (select count(*) from public.broadcast_audience('all'))       as الكل,
         (select count(*) from public.broadcast_audience('providers')) as مزوّدون,
         (select count(*) from public.broadcast_audience('customers')) as عملاء,
         (select count(*) from public.app_users)                       as الجدول`)
ok('إيقافُ حسابٍ ينقص الجمهور واحداً', Number(counts.الكل) === before - 1)
ok('والمزوّدون والعملاء يقتسمون الجمهور بلا تداخل',
   Number(counts.مزوّدون) + Number(counts.عملاء) === Number(counts.الكل))
ok('وفي القاعدة مزوّدون فعلاً — وإلّا لم يقس الاختبار شيئاً', Number(counts.مزوّدون) > 0)

// ── ١. حملةٌ للمزوّدين: تصل صناديقهم وحدهم ───────────────────────────────────
const campaign = await one(`
  insert into public.push_notifications (title, body, audience, status)
       values ('تحديث العمولة', 'اقرأ الشروط الجديدة', 'providers', 'draft')
  returning id`)

await db.exec(`select set_config('test.uid', '${auid}', false)`)
await db.exec(`set role authenticated`)

const sent = await one(`select public.api_admin_broadcast($1) as عدد`, [campaign.id])
ok('عددُ المستلمين = عددُ المزوّدين', Number(sent.عدد) === Number(counts.مزوّدون))

await db.exec(`reset role`)
const landed = await one(`
  select count(*) as صفوف,
         count(*) filter (
           where exists (select 1 from public.service_providers p
                          where p.user_id = n.user_id)) as لمزوّدين
    from public.notifications n
   where n.data ->> 'broadcast_id' = $1`, [campaign.id])
ok('وصفوفٌ في الصندوق فعلاً — لا حالةٌ في جدول الحملات وحدها',
   Number(landed.صفوف) === Number(counts.مزوّدون))
ok('وكلُّها لمقدّمي خدمة لا لعملاء',
   Number(landed.لمزوّدين) === Number(landed.صفوف))

const after = await one(
  `select status, recipients, sent_at from public.push_notifications where id = $1`,
  [campaign.id])
ok('والحملة صارت «مُرسل» بعددٍ حقيقي',
   after.status === 'sent' && Number(after.recipients) === Number(counts.مزوّدون))

// ── ٢. ولا تُرسَل مرّتين ─────────────────────────────────────────────────────
await db.exec(`select set_config('test.uid', '${auid}', false)`)
await db.exec(`set role authenticated`)
let raised = null
try {
  await db.query(`select public.api_admin_broadcast($1)`, [campaign.id])
} catch (e) { raised = e.message }
ok('وإعادةُ الإرسال تُردّ', /أُرسلت هذه الحملة/.test(raised ?? ''))
await db.exec(`reset role`)
ok('ولا صفَّ زائدٌ في الصندوق',
   Number((await one(`select count(*) as ع from public.notifications
                       where data ->> 'broadcast_id' = $1`, [campaign.id])).ع)
   === Number(counts.مزوّدون))

// ── ٣. والموقوف لا يصله شيء ولو كانت للجميع ─────────────────────────────────
const forAll = await one(`
  insert into public.push_notifications (title, body, audience, status)
       values ('عيدكم مبارك', 'كل عام وأنتم بخير', 'all', 'draft')
  returning id`)
await db.exec(`select set_config('test.uid', '${auid}', false)`)
await db.exec(`set role authenticated`)
await db.query(`select public.api_admin_broadcast($1)`, [forAll.id])
await db.exec(`reset role`)
ok('الموقوف لا يصله شيء',
   Number((await one(`select count(*) as ع from public.notifications
                       where data ->> 'broadcast_id' = $1 and user_id = $2`,
                     [forAll.id, banned.id])).ع) === 0)

// ── ٤. ومن لا صلاحية له لا يُرسل ────────────────────────────────────────────
//
// عميلٌ عاديّ — لا صفَّ له في `admins` — يُنادي الدالّة مباشرةً كما يستطيع أي
// حاملِ جلسة. والحارس في الدالّة لا في الشاشة.
const cuid = '22222222-2222-2222-2222-222222222222'
const customer = await one(`select id from public.app_users where status <> 'suspended' order by email limit 1`)
await db.exec(`
  insert into auth.users (id, email) values ('${cuid}', 'c@sdd.company')
    on conflict (id) do nothing;
  update public.app_users set auth_user_id = '${cuid}' where id = '${customer.id}';`)

const third = await one(`
  insert into public.push_notifications (title, body, audience, status)
       values ('خصم', 'من عندي أنا', 'all', 'draft')
  returning id`)
await db.exec(`select set_config('test.uid', '${cuid}', false)`)
await db.exec(`set role authenticated`)
raised = null
try {
  await db.query(`select public.api_admin_broadcast($1)`, [third.id])
} catch (e) { raised = e.message }
ok('والعميل لا يُرسل حملةً باسم المنصّة', /صلاحية/.test(raised ?? ''))
await db.exec(`reset role`)

// ── ٥. والمجدولة: ما حان وقته يُرسَل، وما لم يَحِن يبقى ──────────────────────
const due = await one(`
  insert into public.push_notifications (title, body, audience, status, scheduled_at)
       values ('حان', 'نصّ', 'all', 'scheduled', now() - interval '1 minute')
  returning id`)
const later = await one(`
  insert into public.push_notifications (title, body, audience, status, scheduled_at)
       values ('لم يَحِن', 'نصّ', 'all', 'scheduled', now() + interval '1 day')
  returning id`)

ok('دورةٌ واحدة أرسلت حملةً واحدة',
   Number((await one(`select public.send_due_broadcasts() as ع`)).ع) === 1)
ok('التي حان وقتها صارت «مُرسل»',
   (await one(`select status from public.push_notifications where id = $1`, [due.id])).status
   === 'sent')
ok('والتي لم يَحِن وقتها بقيت مجدولة',
   (await one(`select status from public.push_notifications where id = $1`, [later.id])).status
   === 'scheduled')
ok('ودورةٌ ثانيةٌ لا تُرسل شيئاً',
   Number((await one(`select public.send_due_broadcasts() as ع`)).ع) === 0)

// ── ٦. التفريغ: يمحو الدفتر ولا يمسّ صناديق الناس ───────────────────────────
const inboxBefore = Number((await one(`select count(*) as ع from public.notifications`)).ع)
ok('وفي الصناديق صفوفٌ قبل التفريغ — وإلّا لم يقس الاختبار شيئاً', inboxBefore > 0)

// العميل لا يفرّغ سجلّ المنصّة.
await db.exec(`select set_config('test.uid', '${cuid}', false)`)
await db.exec(`set role authenticated`)
raised = null
try {
  await db.query(`select public.api_clear_push_log()`)
} catch (e) { raised = e.message }
ok('والعميل لا يفرّغ سجل الإشعارات', /يملك الكتابة/.test(raised ?? ''))
await db.exec(`reset role`)

const campaignsBefore = Number(
  (await one(`select count(*) as ع from public.push_notifications`)).ع)
await db.exec(`select set_config('test.uid', '${auid}', false)`)
await db.exec(`set role authenticated`)
const purged = Number((await one(`select public.api_clear_push_log() as ع`)).ع)
await db.exec(`reset role`)

ok('والعدد الراجع = ما كان في السجل', purged === campaignsBefore && purged > 0)
ok('والسجل فرغ',
   Number((await one(`select count(*) as ع from public.push_notifications`)).ع) === 0)
// **وهذا أهمّ تأكيدٍ هنا:** إشعارٌ وصل جوال أحدهم لا يُمحى بتنظيف دفترٍ عندنا.
ok('وصناديق المستخدمين لم تُمسّ',
   Number((await one(`select count(*) as ع from public.notifications`)).ع) === inboxBefore)
ok('والتفريغ خلّف أثره في سجل العمليات',
   Number((await one(`select count(*) as ع from public.audit_log
                       where action = 'notification.purge'`)).ع) === 1)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات broadcast.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
