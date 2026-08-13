/**
 * صلاحيات المسؤولين بالمجال — بهويات حقيقية بدور `authenticated`.
 *
 * الجدول أدناه هو المواصفة: لكل دور، ما يجب أن ينجح وما يجب أن يرتدّ. وهو
 * يفحص RLS لا الواجهة — الواجهة تُخفي الأزرار، وRLS هي التي تمنع الطلب.
 */
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid;
  $$;
  create role anon;
  create role authenticated;
`)

for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql']) {
  await db.exec(read(f))
  console.log(`✓ ${f}`)
}

const ROLES = ['owner', 'manager', 'operations', 'finance', 'support', 'moderator', 'viewer']
const uid = {}
for (const role of ROLES) {
  uid[role] = crypto.randomUUID()
  await db.query(`insert into auth.users (id, email) values ($1, $2)`, [uid[role], `${role}@test.ye`])
  await db.query(`insert into public.admins (user_id, email, role) values ($1, $2, $3)`,
    [uid[role], `${role}@test.ye`, role])
}

const as = async (who, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid[who] ?? ''])
  await db.exec(`set role authenticated`)
  try {
    return await db.query(sql, params)
  } finally {
    await db.exec(`reset role`)
  }
}

let failures = 0
const ok = (label, cond, extra = '') => {
  if (!cond) failures++
  return `${cond ? '✅' : '❌'} ${label}${extra ? ` — ${extra}` : ''}`
}

/** هل غيّر هذا الدور صفاً فعلاً؟ RLS لا ترفع خطأ في UPDATE — تُصفّر المطابقة. */
async function canUpdate(role, sql, params) {
  const res = await as(role, sql, params)
  return (res.affectedRows ?? res.rows?.length ?? 0) > 0
}

const ids = {}
ids.category = (await db.query(`select id from public.service_categories limit 1`)).rows[0].id
ids.provider = (await db.query(`select id from public.service_providers limit 1`)).rows[0].id
ids.payment = (await db.query(`select id from public.payments limit 1`)).rows[0].id
ids.review = (await db.query(`select id from public.reviews limit 1`)).rows[0].id
ids.booking = (await db.query(`select id from public.bookings limit 1`)).rows[0].id

// ---------------------------------------------------------------------------
// المواصفة: [المجال، هل يكتب؟] لكل دور
// ---------------------------------------------------------------------------
const EXPECT = {
  //           catalog directory finance trust  support settings admins
  owner:      [true,   true,     true,   true,  true,   true,    true],
  manager:    [true,   true,     true,   true,  true,   true,    false],
  operations: [true,   true,     true,   false, false,  false,   false],
  finance:    [false,  false,    true,   false, false,  false,   false],
  support:    [false,  false,    false,  false, true,   false,   false],
  moderator:  [false,  false,    false,  true,  false,  false,   false],
  viewer:     [false,  false,    false,  false, false,  false,   false],
}

console.log('\n=== الكتابة بالمجال ===')
for (const [role, expected] of Object.entries(EXPECT)) {
  const got = [
    await canUpdate(role, `update public.service_categories set description = description where id = $1`, [ids.category]),
    await canUpdate(role, `update public.service_providers set bio = bio where id = $1`, [ids.provider]),
    await canUpdate(role, `update public.payments set description = description where id = $1`, [ids.payment]),
    await canUpdate(role, `update public.reviews set comment = comment where id = $1`, [ids.review]),
    // خدمة العملاء: صلاحية الكتابة تُقاس بدالة المجال مباشرةً، فلا تذكرة بعد.
    (await as(role, `select public.can_write_area('support') as v`)).rows[0].v,
    await canUpdate(role, `update public.app_settings set support_email = support_email`, []),
    (await as(role, `select public.can_write_area('admins') as v`)).rows[0].v,
  ]
  const areas = ['الأقسام', 'مقدّمو الخدمة', 'المدفوعات', 'التقييمات', 'التذاكر', 'الإعدادات', 'المسؤولون']
  const line = got.map((g, i) => `${g === expected[i] ? '' : '⚠️'}${areas[i]}:${g ? '✏️' : '—'}`).join('  ')
  console.log(ok(role.padEnd(11), got.every((g, i) => g === expected[i]), line))
}

console.log('\n=== حجب المال عن غير أهله ===')
// المال هو المجال الوحيد الذي تُقيَّد قراءته: من يردّ على تذكرة لا يحتاج أن
// يرى عمولات المنصة ومستحقات الشركاء.
for (const role of ['support', 'moderator', 'viewer']) {
  const { rows } = await as(role, `select count(*)::int n from public.payments`)
  console.log(ok(`${role} لا يرى المدفوعات`, rows[0].n === 0, `يرى ${rows[0].n}`))
  const { rows: st } = await as(role, `select count(*)::int n from public.settlements`)
  console.log(ok(`${role} لا يرى المستحقات`, st[0].n === 0, `يرى ${st[0].n}`))
}
for (const role of ['owner', 'manager', 'operations', 'finance']) {
  const { rows } = await as(role, `select count(*)::int n from public.payments`)
  console.log(ok(`${role} يرى المدفوعات`, rows[0].n > 0, `يرى ${rows[0].n}`))
}

console.log('\n=== ما يحتاجه كل دور للعمل ===')
const { rows: sb } = await as('support', `select count(*)::int n from public.bookings`)
console.log(ok('خدمة العملاء تقرأ الحجوزات', sb[0].n > 0, `${sb[0].n}`))
const { rows: su } = await as('support', `select count(*)::int n from public.app_users`)
console.log(ok('وتقرأ العملاء', su[0].n > 0, `${su[0].n}`))
const { rows: fb } = await as('finance', `select count(*)::int n from public.bookings`)
console.log(ok('المحاسب يقرأ الحجوزات', fb[0].n > 0, `${fb[0].n}`))

console.log('\n=== لا أحد يرقّي نفسه ===')
// من يعدّل صفاً في admins يستطيع أن يرفع نفسه مالكاً، فأي دور يُمنح ذلك يصير
// مالكاً فعلياً. وكذلك مصفوفة الصلاحيات نفسها.
for (const role of ['manager', 'operations', 'finance', 'support', 'moderator', 'viewer']) {
  const changed = await canUpdate(role, `update public.admins set role = 'owner' where user_id = $1`, [uid[role]])
  console.log(ok(`${role} لا يرقّي نفسه`, !changed))
  const matrix = await canUpdate(role,
    `update public.admin_areas set level = 'write' where role = $1 and area = 'finance'`, [role])
  console.log(ok(`${role} لا يوسّع مصفوفته`, !matrix))
}
const ownerCan = await canUpdate('owner', `update public.admins set role = 'viewer' where user_id = $1`, [uid.moderator])
console.log(ok('المالك يغيّر أدوار غيره', ownerCan))

console.log('\n=== الدور القديم admin رُحِّل ===')
const { rows: legacy } = await db.query(`select count(*)::int n from public.admins where role = 'admin'`)
console.log(ok('لم يبقَ أحد بدور admin', legacy[0].n === 0, `${legacy[0].n}`))

console.log(failures === 0 ? '\n🎉 كل اختبارات الصلاحيات نجحت.' : `\n❌ ${failures} فشل`)
await db.close()
process.exit(failures === 0 ? 0 : 1)
