/**
 * الاشتراكات: من يطلب، ومتى يُفعَّل، وماذا يُسحب عند الانتهاء.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن ما له سعرٌ **لا يُفعَّل قبل وصول المال** — وإلّا اشترك الناس مجّاناً.
 *   ٢. وأن التفعيل يقع بتأكيد الحوالة نفسها، من أي بابٍ أُكِّدت.
 *   ٣. وأن «الظهور المميز» يقع فعلاً ويُسحب عند الانتهاء — وعدٌ لا يُنفَّذ
 *      أسوأ من وعدٍ لا يُقال.
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
                 'invitations.sql', 'payments_app.sql']) {
  await db.exec(read(f))
}
const file = read('subscriptions.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مزوّدٌ بحساب، ومسؤولٌ مالك ────────────────────────────────────────
const puid = '66666666-6666-6666-6666-666666666666'
const auid = '77777777-7777-7777-7777-777777777777'
const provider = await one(`select id from public.service_providers limit 1`)
await db.exec(`
  delete from public.provider_subscriptions where provider_id = '${provider.id}';
  insert into auth.users (id, email) values ('${puid}', 'p3@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${puid}', 'صاحب قاعة', 'p3@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${puid}';
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${puid}'),
         is_featured = false
   where id = '${provider.id}';

  insert into auth.users (id, email) values ('${auid}', 'a3@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a3@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)

const gold = await one(
  `select id, price from public.subscription_plans where price > 0
    and array_to_string(perks, '،') like '%ظهور مميز%' limit 1`)
const free = await one(`select id from public.subscription_plans where price = 0 limit 1`)
ok('في الباقات واحدةٌ مدفوعةٌ بظهورٍ مميز — وإلّا لم يقس الاختبار شيئاً',
   gold !== undefined && free !== undefined)

const asProvider = async () => {
  await db.exec(`select set_config('test.uid', '${puid}', false)`)
  await db.exec(`set role authenticated`)
}
const asAdmin = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${auid}', false)`)
  await db.exec(`set role authenticated`)
}

// ── ١. المدفوعة تُطلب معلّقةً، ولا تُفعَّل ────────────────────────────────────
await asProvider()
const sub = await one(`select * from public.api_subscribe($1, 'jawali', '777123456')`,
                      [gold.id])
await db.exec(`reset role`)

ok('الاشتراك يقع معلّقاً لا نشطاً', sub.status === 'pending')
ok('ولا يصير المزوّد مميّزاً قبل الدفع',
   (await one(`select is_featured from public.service_providers where id = $1`,
              [provider.id])).is_featured === false)

const pay = await one(`select * from public.payments where id = $1`, [sub.payment_id])
ok('وحوالةٌ معلّقة بمبلغ الباقة',
   pay.status === 'pending' && Number(pay.amount) === Number(gold.price))
ok('ونوعُها «اشتراك» فتظهر في صفحة المدفوعات', pay.kind === 'subscription')
ok('وحصّةُ المنصّة كامل المبلغ — لا شريك في الاشتراك',
   Number(pay.platform_share) === Number(gold.price) && Number(pay.net_amount) === 0)

// ── ٢. ولا طلبَ ثانٍ فوق معلّق ───────────────────────────────────────────────
await asProvider()
let raised = null
try {
  await db.query(`select public.api_subscribe($1)`, [free.id])
} catch (e) { raised = e.message }
ok('وطلبٌ ثانٍ فوق معلّقٍ يُردّ', /قيد التأكيد/.test(raised ?? ''))
await db.exec(`reset role`)

// ── ٣. تأكيد الحوالة يُفعّل الاشتراك ويمنح الميزة ────────────────────────────
await asAdmin()
await db.query(`select public.api_admin_confirm_payment($1, 'REF-SUB')`, [pay.id])
await db.exec(`reset role`)

const active = await one(`select * from public.provider_subscriptions where id = $1`, [sub.id])
ok('التأكيد يُفعّل الاشتراك', active.status === 'active')
ok('ويصير المزوّد مميّزاً',
   (await one(`select is_featured from public.service_providers where id = $1`,
              [provider.id])).is_featured === true)
ok('والمدّة تبدأ من لحظة التفعيل لا من لحظة الطلب',
   new Date(active.ends_at).getTime() > Date.now() + 20 * 24 * 3600 * 1000)

// ── ٤. والانتهاء يسحب ما مُنح ────────────────────────────────────────────────
//
// **وهذا ما ينكسر بصمت:** اشتراكٌ ينتهي ويبقى صاحبُه مميّزاً — فمن دفع مرّةً
// نال الأبد، ولا يدفع أحدٌ بعدها.
// القيد `subscription_period` يلزم أن تكون النهاية بعد البداية، فيُزحف
// الاثنان معاً — والاختبار يحاكي مرور الشهر لا يخترق قيداً.
await db.query(
  `update public.provider_subscriptions
      set starts_at = now() - interval '31 days',
          ends_at   = now() - interval '1 day'
    where id = $1`, [sub.id])
const expired = Number((await one(`select public.expire_subscriptions() as ع`)).ع)
ok('دورةُ الانتهاء تُنهي المستحقّ', expired >= 1)
ok('وتسحب الظهور المميّز',
   (await one(`select is_featured from public.service_providers where id = $1`,
              [provider.id])).is_featured === false)
ok('والحالة صارت «منتهٍ»',
   (await one(`select status from public.provider_subscriptions where id = $1`,
              [sub.id])).status === 'expired')

// ── ٥. والمجّانية تُفعَّل فوراً بلا حوالة ────────────────────────────────────
await asProvider()
const gift = await one(`select * from public.api_subscribe($1)`, [free.id])
await db.exec(`reset role`)
ok('المجّانية نشطةٌ من فورها', gift.status === 'active')
ok('وبلا حوالة', gift.payment_id === null)

// ── ٦. ومن ليس مزوّداً لا يشترك ──────────────────────────────────────────────
const cuid = '88888888-8888-8888-8888-888888888888'
await db.exec(`
  insert into auth.users (id, email) values ('${cuid}', 'c3@sdd.company')
    on conflict (id) do nothing;
  select set_config('test.uid', '${cuid}', false);`)
await db.exec(`set role authenticated`)
raised = null
try {
  await db.query(`select public.api_subscribe($1)`, [free.id])
} catch (e) { raised = e.message }
ok('ومن ليس مزوّداً يُردّ', /لمقدّمي الخدمة/.test(raised ?? ''))
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات subscriptions.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
