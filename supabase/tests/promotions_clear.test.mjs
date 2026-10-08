// **«تفريغ المنتهية» — `api_admin_clear_promotions` في `promotions_clear.sql`.**
//
// اختار صاحبُ المنصّة (أ أ): المنتهيةُ والملغاةُ وحدها، والمالكُ وحده. فيُقاس
// بأدوار القاعدة الحقيقيّة (`set local role authenticated` وهويّةُ صاحبها):
// ما يُحذف، وما يبقى، ومَن يُردّ — **وأنّ المالَ لا يُمسّ**.
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
  audit_security security_hardening security_fixes wallet banners promotions_clear`.split(/\s+/)

const db = new PGlite()
await db.exec(SUPABASE)
for (const f of ORDER) await db.exec(read(`${f}.sql`))
await db.exec(read('promotions_clear.sql')) // إعادةُ اللصق آمنة

const q = async (sql, params = []) => (await db.query(sql, params)).rows
const one = async (sql, params = []) => (await q(sql, params))[0]
const as = async (auth, sql, params = []) => {
  await db.exec('begin')
  try {
    await db.exec(`set local role ${auth ? 'authenticated' : 'anon'}`)
    await db.query(`select set_config('request.jwt.claim.sub', $1, true)`, [auth ?? ''])
    const rows = (await db.query(sql, params)).rows
    await db.exec('commit')
    return rows
  } catch (e) {
    await db.exec('rollback')
    return { error: e.message }
  }
}
const refused = (r) => !Array.isArray(r)

const OWNER = '33333333-3333-4333-8333-333333333333'
const MANAGER = '44444444-4444-4444-8444-444444444444'
await db.exec(`insert into auth.users (id, email) values ('${OWNER}', 'o@x.com'), ('${MANAGER}', 'm@x.com');
  insert into public.admins (user_id, email, role) values ('${OWNER}', 'o@x.com', 'owner'), ('${MANAGER}', 'm@x.com', 'manager');`)

await db.exec(`delete from public.promotions`)
const provider = await one(`select id, business_name from public.service_providers where status = 'verified' order by id limit 1`)
const img = (n) => `https://x.supabase.co/storage/v1/object/public/ad-banners/${n}.webp`
const add = async (name, status, ends, extra = {}) => (await one(`insert into public.promotions
    (provider_name, kind, placement, status, starts_at, ends_at, image_url, image_urls, payment_id)
  values ($1, 'banner', 'home', $2, now() - interval '30 days', now() + $3::interval, $4, $5, $6) returning id`,
  [name, status, ends, extra.image ?? '', extra.images ?? [], extra.payment ?? null])).id

const ended = await add('منتهية', 'ended', '-2 days', { image: img('e1'), images: [img('e1'), img('e2')] })
const cancelled = await add('ملغاة', 'cancelled', '5 days', { image: img('c1') })
const lapsed = await add('انتهت مدّتها', 'active', '-1 hour', { images: [img('l1')] })
const live = await add('جارية', 'active', '10 days', { image: img('live') })
const later = await add('مجدولة', 'scheduled', '40 days', { image: img('later') })
// طلبُ مزوّدٍ حوالتُه معلّقةٌ وقد فات تاريخُه — يبقى، وإلّا قُبض المالُ بلا ظهور.
const pay = await one(`insert into public.payments (reference, provider_id, kind, description, amount,
    platform_share, net_amount, method, status)
  values ('PRM-CLR-1', $1, 'promotion', 'ظهور مميز', 14000, 14000, 0, 'jawali', 'pending') returning id`, [provider.id])
const unpaid = await add('طلبٌ معلّق', 'scheduled', '-1 day', { payment: pay.id })
// ودفعةٌ مؤكَّدةٌ لحملةٍ منتهية — المالُ لا يُمسّ.
await db.query(`insert into public.payments (reference, provider_id, kind, description, amount,
    platform_share, net_amount, method, status)
  values ('PRM-CLR-2', $1, 'promotion', 'ظهور مميز', 9000, 9000, 0, 'jawali', 'paid')`, [provider.id])
const paidBefore = (await one(`select count(*)::int n, coalesce(sum(amount), 0)::int s from public.payments`))

const exists = async (id) => (await q(`select 1 from public.promotions where id = $1`, [id])).length === 1

// ── مَن يُردّ ────────────────────────────────────────────────────────────────
ok('**«مدير» يُردّ** — الزرُّ للمالك وحده', refused(await as(MANAGER, `select * from public.api_admin_clear_promotions()`)))
ok('والزائرُ يُردّ', refused(await as(null, `select * from public.api_admin_clear_promotions()`)))
ok('ولم يُحذف شيءٌ بمحاولتهما', await exists(ended) && await exists(cancelled) && await exists(lapsed))

// ── المالك ──────────────────────────────────────────────────────────────────
const r = await as(OWNER, `select * from public.api_admin_clear_promotions()`)
ok('والمالكُ يُفرِّغ', Array.isArray(r), JSON.stringify(r))
const res = Array.isArray(r) ? r[0] : { deleted: -1, image_urls: [] }
ok('**المنتهيةُ والملغاةُ تُحذف**', !(await exists(ended)) && !(await exists(cancelled)))
ok('**وما انقضى تاريخُه وعمودُه «جارية» يُحذف** — «انتهت مدّتها»', !(await exists(lapsed)))
ok('**والجاريةُ والمجدولةُ تبقى**', await exists(live) && await exists(later))
ok('**وطلبُ مزوّدٍ حوالتُه معلّقةٌ يبقى** — وإلّا قُبض المالُ بلا ظهور', await exists(unpaid))
ok('والعدُّ ما حُذف', res.deleted === 3, String(res.deleted))
const urls = [...(res.image_urls ?? [])].sort()
ok('**وتُرجَع روابطُ صورها بلا تكرار** — ليحذفها العميلُ من التخزين',
   JSON.stringify(urls) === JSON.stringify([img('c1'), img('e1'), img('e2'), img('l1')].sort()), JSON.stringify(urls))
ok('ولا تُرجَع صورُ ما بقي', !urls.includes(img('live')) && !urls.includes(img('later')))
const paidAfter = (await one(`select count(*)::int n, coalesce(sum(amount), 0)::int s from public.payments`))
ok('**والمالُ لا يُمسّ** — الدفعاتُ كما كانت', paidAfter.n === paidBefore.n && paidAfter.s === paidBefore.s,
   `${JSON.stringify(paidBefore)} → ${JSON.stringify(paidAfter)}`)

const again = await as(OWNER, `select * from public.api_admin_clear_promotions()`)
ok('وتفريغٌ ثانٍ لا يجد شيئاً', Array.isArray(again) && again[0].deleted === 0 && again[0].image_urls.length === 0)

console.log(fail === 0 ? '\nكلُّ اختبارات التفريغ نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
