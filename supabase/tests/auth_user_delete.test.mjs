/**
 * حذف حسابٍ من `auth.users` يجب أن ينجح دائماً.
 *
 * العطل الذي أوجب هذا الملف: `admin_invitations.accepted_by` كان
 * `on delete set null`، وفوقه شرطٌ يوجب أن يكون `accepted_at` و`accepted_by`
 * معاً أو لا يكونا. فحذف الحساب يُصفّر أحدهما ويترك الآخر، فينكسر الشرط
 * وتفشل العملية — وتصل الرسالة إلى لوحة Supabase هكذا: «Database error
 * deleting user». لا جدول ولا شرط ولا عمود، فيبدو العطل في Supabase وهو
 * في مخططنا نحن.
 *
 * ولأن العطل وُلد من **تفاعل** قيدين كلٌّ منهما سليمٌ وحده، لا يكفي أن
 * نفحص التعريفات: الاختبار يحذف حساباً له صفٌّ في كل جدولٍ يشير إلى
 * `auth.users`، فيمرّ على كل تفاعلٍ ممكن دفعةً واحدة.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')
const FILES = ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql']

const fresh = async () => {
  const db = new PGlite()
  await db.exec(`
    create schema if not exists auth;
    create table if not exists auth.users (id uuid primary key, email text);
    create or replace function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create role anon; create role authenticated;
  `)
  for (const f of FILES) await db.exec(read(f))
  return db
}

let fail = 0
const check = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const U = '55555555-5555-5555-5555-555555555555'

/** يزرع صفّاً في كل جدولٍ يشير إلى auth.users. */
const seedEverywhere = (db) =>
  db.exec(`
    insert into auth.users (id, email) values ('${U}', 'staff@aras.ye');
    insert into public.admins (user_id, email, role)
      values ('${U}', 'staff@aras.ye', 'support');
    insert into public.app_users (auth_user_id, full_name, email)
      values ('${U}', 'الموظف', 'staff@aras.ye');
    insert into public.admin_invitations
      (email, role, token, invited_by, accepted_at, accepted_by)
      values ('staff@aras.ye', 'support', 'TOKEN12345', 'owner@aras.ye', now(), '${U}');
    insert into public.push_notifications (title, body, audience, status, created_by)
      values ('إعلان', 'نصّ', 'all', 'sent', '${U}');
  `)

console.log('=== كل الجداول التي تشير إلى auth.users ===')
{
  const db = await fresh()
  const fks = await db.query(`
    select c.conrelid::regclass::text as tbl, a.attname as col, c.confdeltype as act
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
     where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
     order by 1`)
  const NAME = { a: 'NO ACTION', r: 'RESTRICT', c: 'CASCADE', n: 'SET NULL', d: 'SET DEFAULT' }
  for (const r of fks.rows) console.log(`   · ${r.tbl}.${r.col} → ${NAME[r.act]}`)
  check(
    'لا مفتاح يمنع الحذف صراحةً',
    fks.rows.every((r) => r.act !== 'a' && r.act !== 'r'),
  )

  await seedEverywhere(db)
  let ok = true
  let msg = ''
  try {
    await db.exec(`delete from auth.users where id = '${U}'`)
  } catch (e) {
    ok = false
    msg = e.message
  }
  check('حذف حسابٍ له صفٌّ في كل جدول', ok, msg)
  check(
    'ولم يبقَ له صفٌّ في المسؤولين',
    (await db.query(`select count(*)::int as n from public.admins where user_id = '${U}'`))
      .rows[0].n === 0,
  )
  check(
    'ولا دعوةٌ يتيمة تقول «قُبلت»',
    (await db.query(`select count(*)::int as n from public.admin_invitations
                      where lower(email) = 'staff@aras.ye'`)).rows[0].n === 0,
  )
  check(
    'وإشعاره باقٍ بلا صاحب لا محذوفاً',
    (await db.query(`select count(*)::int as n from public.push_notifications
                      where title = 'إعلان' and created_by is null`)).rows[0].n === 1,
  )
}

console.log('\n=== ترحيل قاعدةٍ قائمة بالقيد القديم ===')
{
  // هذا هو مسار من ثبّت نسخةً سابقة: الجدول موجودٌ بـ set null، و
  // `create table if not exists` لا يمسّه. فالترحيل وحده هو ما يُصلحه.
  const db = await fresh()
  await db.exec(`
    alter table public.admin_invitations drop constraint admin_invitations_accepted_by_fkey;
    alter table public.admin_invitations
      add constraint admin_invitations_accepted_by_fkey
      foreign key (accepted_by) references auth.users (id) on delete set null;
  `)
  await seedEverywhere(db)

  let brokeBefore = false
  try {
    await db.exec(`delete from auth.users where id = '${U}'`)
  } catch {
    brokeBefore = true
  }
  check('العطل يظهر بالقيد القديم', brokeBefore)

  // إعادة تشغيل الملف — وهو ما سيفعله المستخدم — تُصلحه.
  await db.exec(read('invitations.sql'))
  let ok = true
  let msg = ''
  try {
    await db.exec(`delete from auth.users where id = '${U}'`)
  } catch (e) {
    ok = false
    msg = e.message
  }
  check('وإعادة تشغيل invitations.sql تُصلحه', ok, msg)

  // والملف آمنٌ للتكرار: تشغيله ثانيةً لا يكسر شيئاً.
  await db.exec(read('invitations.sql'))
  const act = (await db.query(`select confdeltype as a from pg_constraint
                                where conname = 'admin_invitations_accepted_by_fkey'`)).rows[0].a
  check('والتشغيل المكرّر يُبقيه على cascade', act === 'c', act)
}

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 لا شيء في المخطط يمنع حذف حساب.')
