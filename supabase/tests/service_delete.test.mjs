// حذفُ الخدمة — ويُمنع ما دام عليها حجزٌ قادم.
//
// ── وأخطرُ ما يُقاس هنا ──────────────────────────────────────────────────────
//
// **١) الحارسُ في القاعدة لا في الشاشة.** سياسةُ `provider_services_owner`
// تسمح لصاحب الخدمة بالحذف مباشرةً، فحارسٌ في `services.dart` يُتجاوَز بملفِّ
// APK مفكوك.
//
// **٢) ولا يحذف أحدٌ خدمةَ غيره.**
//
// **٣) والوسائطُ تُعاد مساراتُها.** قاعدةُ البيانات لا تحذف ملفّاتِ السلّة،
// فما لم تُعَد المساراتُ بقيت الملفّاتُ تأكل المساحةَ ورابطُها يعمل.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;`)

// هيكلٌ مصغَّرٌ من مخطَّط التخزين — `service_media.sql` يكتب عليه.
await db.exec(`
  create schema storage;
  create table storage.buckets (
    id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`)

for (const f of ['install.sql', 'apply.sql', 'service_media.sql', 'service_delete.sql']) {
  await db.exec(read(f))
}

// ── مزوّدان وخدماتُهما ──────────────────────────────────────────────────────
const MINE = '11111111-1111-1111-1111-111111111111'
const OTHER = '22222222-2222-2222-2222-222222222222'

await db.exec(`
  insert into auth.users (id, email) values
    ('${MINE}', 'mine@test'), ('${OTHER}', 'other@test');

  insert into public.app_users (id, auth_user_id, full_name, email)
  values ('aaaaaaaa-0000-0000-0000-000000000001', '${MINE}', 'صاحبي', 'mine@test'),
         ('aaaaaaaa-0000-0000-0000-000000000002', '${OTHER}', 'غيري', 'other@test');

  insert into public.service_providers (id, user_id, full_name, business_name, email, status, verified_at)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
          'صاحبي', 'قاعة التاج', 'mine@test', 'verified', now()),
         ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002',
          'غيري', 'قاعة أخرى', 'other@test', 'verified', now());

  insert into public.service_categories (id, name, slug)
  values ('dddddddd-0000-0000-0000-000000000001', 'قاعات', 'halls');

  insert into public.provider_services (id, provider_id, category_id, title, price, unit)
  values ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'قاعة', 1000, 'يوم'),
         ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'خيمة', 2000, 'يوم'),
         ('cccccccc-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000001', 'خدمةُ غيري', 500, 'يوم');

  insert into public.service_media (service_id, provider_id, kind, path)
  values ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'image', 'p1/s1/a.jpg'),
         ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'image', 'p1/s1/b.jpg');
`)

// **والضبطُ للجلسة لا للمعاملة.** `set local` و`set_config(..., true)` ينتهيان
// بانتهاء المعاملة، وكلُّ نداءٍ هنا معاملةٌ وحدَه — فتضيع الهويّةُ قبل أن
// يُنادى شيء، وتردّ الدالّةُ «لا ملفَّ مزوّدٍ لهذا الحساب».
const as = async (uid, sql, params) => {
  await db.exec(`set role authenticated; select set_config('test.uid', '${uid}', false);`)
  return db.query(sql, params)
}
const del = (uid, id) =>
  as(uid, 'select * from public.api_delete_service($1)', [id])

// ── ١) خدمةٌ بلا حجوزاتٍ تُحذف، وتُعاد مساراتُ وسائطها ──────────────────────
{
  const { rows } = await del(MINE, 'cccccccc-0000-0000-0000-000000000001')
  assert.equal(rows[0].deleted, true, 'لم تُحذف خدمةٌ بلا حجوزات')
  assert.equal(rows[0].blocking_date, null)
  assert.deepEqual([...rows[0].paths].sort(), ['p1/s1/a.jpg', 'p1/s1/b.jpg'],
    'لم تُعَد مساراتُ الوسائط — فتبقى في السلّة بلا صاحب')

  await db.exec('reset role')
  const { rows: left } = await db.query(
    `select count(*)::int n from public.provider_services
      where id = 'cccccccc-0000-0000-0000-000000000001'`)
  assert.equal(left[0].n, 0, 'بقيت الخدمة')

  await db.exec('reset role')
  const { rows: media } = await db.query(
    `select count(*)::int n from public.service_media
      where service_id = 'cccccccc-0000-0000-0000-000000000001'`)
  assert.equal(media[0].n, 0, 'بقيت صفوفُ الوسائط')
  console.log('✓ خدمةٌ بلا حجوزاتٍ تُحذف، ومساراتُ وسائطها تُعاد')
}

// ── ٢) وحجزٌ قادمٌ يمنع الحذف ───────────────────────────────────────────────
{
  await db.exec(`
    reset role;
    insert into public.bookings (reference, provider_id, service_id, service_title,
                                 event_date, status, total_price, confirmed_at)
    values ('BK-1', 'bbbbbbbb-0000-0000-0000-000000000001',
            'cccccccc-0000-0000-0000-000000000002', 'خيمة',
            current_date + 30, 'confirmed', 2000, now());`)

  const { rows } = await del(MINE, 'cccccccc-0000-0000-0000-000000000002')
  assert.equal(rows[0].deleted, false, 'حُذفت خدمةٌ عليها حجزٌ قادم')
  assert.ok(rows[0].blocking_date, 'لم يُعَد تاريخُ الحجز المانع')

  await db.exec('reset role')
  const { rows: left } = await db.query(
    `select count(*)::int n from public.provider_services
      where id = 'cccccccc-0000-0000-0000-000000000002'`)
  assert.equal(left[0].n, 1, 'اختفت الخدمةُ رغم أنّ الردَّ قال إنّها لم تُحذف')
  console.log('✓ حجزٌ قادمٌ يمنع الحذف، ويُعاد تاريخُه')
}

// ── ٣) وحجزٌ ماضٍ لا يمنع ───────────────────────────────────────────────────
//
// عرسٌ انتهى لا يمنع صاحبَه من ترتيب قائمته.
{
  await db.exec(`
    reset role;
    update public.bookings
       set event_date = current_date - 30, status = 'completed'
     where reference = 'BK-1';`)

  const { rows } = await del(MINE, 'cccccccc-0000-0000-0000-000000000002')
  assert.equal(rows[0].deleted, true, 'منع حجزٌ ماضٍ الحذفَ')

  // **والسجلُّ لا ينقطع:** الحجزُ باقٍ واسمُ الخدمة فيه.
  await db.exec('reset role')
  const { rows: booking } = await db.query(
    `select service_id, service_title from public.bookings where reference = 'BK-1'`)
  assert.equal(booking[0].service_id, null)
  assert.equal(booking[0].service_title, 'خيمة',
    'ضاع اسمُ الخدمة من الحجز — فلا يعرف العميلُ ما حجز')
  console.log('✓ حجزٌ ماضٍ لا يمنع، والحجزُ يبقى باسم خدمته')
}

// ── ٤) ولا يحذف أحدٌ خدمةَ غيره ─────────────────────────────────────────────
{
  await assert.rejects(
    () => del(MINE, 'cccccccc-0000-0000-0000-000000000003'),
    /ليست لك/,
    'حذف مزوّدٌ خدمةَ مزوّدٍ آخر')

  await db.exec('reset role')
  const { rows } = await db.query(
    `select count(*)::int n from public.provider_services
      where id = 'cccccccc-0000-0000-0000-000000000003'`)
  assert.equal(rows[0].n, 1, 'اختفت خدمةُ الآخر')
  console.log('✓ ولا يحذف أحدٌ خدمةَ غيره')
}

// ── ٥) ومعرّفٌ لا وجودَ له يُردّ ولا يُسقط شيئاً ────────────────────────────
{
  await assert.rejects(
    () => del(MINE, '00000000-0000-0000-0000-000000000000'),
    /غير موجودة/)
  console.log('✓ ومعرّفٌ لا وجودَ له يُردّ')
}
