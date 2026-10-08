// **جدولةُ الحملات — `expire_promotions` كما في `banners.sql`.**
//
// كان `banners.sql` يرفع كلَّ صفٍّ `scheduled` إلى `active` حين يحين وقتُه —
// لتظهر لافتةٌ أنشأتها الإدارةُ لتبدأ غداً. لكنّ `scheduled` في هذا الجدول
// معنيان: **«تبدأ لاحقاً»** للافتة الإدارة، و**«حوالتُه لم تُؤكَّد»** لطلب
// المزوّد (`api_request_promotion` يكتبه `scheduled` وبدايتُه الآن ومعه
// `payment_id`). فكانت الدورةُ اليوميّة تُظهر في الرئيسية **مَن لم يدفع**.
//
// فيُقاس هنا أنّ الدورةَ ترفع لافتةَ الإدارة في موعدها، ولا تمسّ طلباً
// مدفوعُه معلّق، وتُنهي ما انقضى — والقاعدةُ مبنيّةٌ بترتيب النشر كلِّه.
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const SUPABASE = `
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;
  grant usage on schema auth to anon, authenticated;
  grant execute on all functions in schema auth to anon, authenticated;
  create schema if not exists storage;
  create table storage.buckets (id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;`

const ORDER = `install seed apply storage support roles invitations profile service_media chat
  notifications push_hook provider_logo payments_app availability subscriptions settlements
  promotions broadcast plan_tasks income chat_media profile_extras coupons location nearby
  category_images app_download share_link service_delete completion_review review_avatars
  phone_verify provider_columns profile_cover plan_cover plan_spend booking_cover booking_delete
  conversation_avatars customer_card phone_verify_attempts presence security_notification_rpcs
  audit_security security_hardening security_fixes wallet banners`.split(/\s+/)

const db = new PGlite()
await db.exec(SUPABASE)
for (const f of ORDER) await db.exec(read(`${f}.sql`))
await db.exec(read('banners.sql')) // إعادةُ اللصق آمنة

const q = async (sql, params = []) => (await db.query(sql, params)).rows
const one = async (sql, params = []) => (await q(sql, params))[0]

await db.exec(`delete from public.promotions`)
const provider = await one(`select id, business_name from public.service_providers
  where status = 'verified' order by id limit 1`)

// (١) طلبُ مزوّدٍ حوالتُه معلّقة — كما يكتبه `api_request_promotion` بالضبط.
const pay = await one(`insert into public.payments (reference, provider_id, kind, description, amount,
    platform_share, net_amount, method, status)
  values ('PRM-TEST-1', $1, 'promotion', 'ظهور مميز 7 يوماً', 14000, 14000, 0, 'jawali', 'pending')
  returning id`, [provider.id])
const unpaid = await one(`insert into public.promotions (provider_id, provider_name, kind, placement,
    amount, status, starts_at, ends_at, payment_id)
  values ($1, $2, 'featured', 'home', 14000, 'scheduled', now() - interval '1 hour',
          now() + interval '7 days', $3) returning id`, [provider.id, provider.business_name, pay.id])

// (٢) لافتةُ إدارةٍ أُنشئت لتبدأ «غداً» — وقد حان غدُها.
const due = await one(`insert into public.promotions (provider_name, kind, placement, status,
    starts_at, ends_at, image_url)
  values ('', 'banner', 'home', 'scheduled', now() - interval '2 hours', now() + interval '20 days',
          'https://x.supabase.co/storage/v1/object/public/ad-banners/due.webp') returning id`)

// (٣) ولافتةٌ موعدُها لم يحن.
const later = await one(`insert into public.promotions (provider_name, kind, placement, status,
    starts_at, ends_at, image_url)
  values ('', 'banner', 'home', 'scheduled', now() + interval '3 days', now() + interval '30 days',
          'https://x.supabase.co/storage/v1/object/public/ad-banners/later.webp') returning id`)

// (٤) ولافتةٌ «جارية» في عمودها وقد انقضت مدّتُها قبل ساعة — ما رآه صاحبُ المنصّة.
const lapsed = await one(`insert into public.promotions (provider_name, kind, placement, status,
    starts_at, ends_at, image_url)
  values ('', 'banner', 'home', 'active', now() - interval '30 days', now() - interval '1 hour',
          'https://x.supabase.co/storage/v1/object/public/ad-banners/lapsed.webp') returning id`)

const status = async (id) => (await one(`select status from public.promotions where id = $1`, [id])).status
const banners = async () => (await q(`select image_url from public.api_active_banners()`)).map((r) => r.image_url)

ok('قبل الدورة: المنقضيةُ لا تُعرض وإن قال عمودُها «جارية»',
   !(await banners()).some((u) => u.endsWith('lapsed.webp')))

await one(`select public.expire_promotions()`)

ok('**وطلبُ مزوّدٍ لم تُؤكَّد حوالتُه يبقى «مجدولاً»** — لا يُعرض مَن لم يدفع',
   (await status(unpaid.id)) === 'scheduled', await status(unpaid.id))
ok('ولا يظهر في شريط المميّزين',
   (await q(`select 1 from public.api_active_promotions() where id = $1`, [unpaid.id])).length === 0)
ok('ولافتةُ الإدارة التي حان موعدُها تُرفع «جارية»', (await status(due.id)) === 'active')
ok('وتظهر في التطبيق', (await banners()).some((u) => u.endsWith('due.webp')))
ok('وما لم يحن موعدُه يبقى «مجدولاً»', (await status(later.id)) === 'scheduled')
ok('والمنقضيةُ تصير «منتهية»', (await status(lapsed.id)) === 'ended')

// والطريقُ الصحيح لطلب المزوّد ما زال يعمل: تأكيدُ الحوالة يُظهره.
await db.query(`update public.payments set status = 'paid' where id = $1`, [pay.id])
ok('وتأكيدُ الحوالة هو ما يُظهره', (await status(unpaid.id)) === 'active')

console.log(fail === 0 ? '\nكلُّ اختبارات جدولة الحملات نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
