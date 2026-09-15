// **من فتح تذكرةً يستطيع حذفَ حسابه.**
//
// ── لماذا هذا الملفّ ────────────────────────────────────────────────────────
//
// كان `support_tickets` يناقض نفسَه:
//
//     user_id     ... on delete set null      -- الحذفُ يُفرّغ العمود
//     constraint ticket_has_owner check (user_id is not null or ...)
//
// فالمفتاحُ يُفرّغ والقيدُ يرفض الفراغ. **ولم يكن هذا عطلاً في مسح البيانة
// وحدَه** — وإن كان هو ما أظهره: سقط `seed.sql` على مشروع الإنتاج بـ
// `23514: violates check constraint "ticket_has_owner"`.
//
// **الأخطرُ أنّ «حذف حسابي» كان يسقط.** `api_delete_my_account` مشحونةٌ في
// التطبيق، وكلُّ من فتح تذكرةَ دعمٍ مرّةً واحدةً لم يكن يستطيع حذفَ حسابه —
// برسالةِ خطأٍ من Postgres لا يفهمها. وحذفُ الحساب شرطٌ عند المتجرين.
//
// واختير **(أ): تذهب التذكرةُ مع صاحبها**.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **لا وجودُ `cascade` في المخطّط — بل الحذفُ نفسُه يقع.** سؤالُ «أهو
// cascade؟» يمرّ على قاعدةٍ أُنشئت قبل الإصلاح ولم تُصلَح، وهي حالُ مشروعه.
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

async function fresh({ files }) {
  const db = new PGlite()
  await db.exec(`
    create schema auth;
    create table auth.users (id uuid primary key, email text);
    create or replace function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.uid', true), '')::uuid;
    $$;
    create role anon;
    create role authenticated;
  `)
  for (const f of files) await db.exec(read(f))
  return db
}

const as = (db, uid, sql) =>
  db.exec(`select set_config('test.uid', '${uid}', false);`).then(() =>
    db.query(sql))

// يفتح تذكرةً بالدالّة المشحونة لا بإدراجٍ مباشر: المرجعُ والأسماءُ تُولَّد
// هناك، وما يُقاس يجب أن يكون ما يصنعه التطبيق.
async function openTicket(db, uid, { asProvider = false } = {}) {
  await db.exec(`select set_config('test.uid', '${uid}', false);`)
  const { rows } = await db.query(
    `select * from public.api_open_ticket('شكوى', 'المتن', 'booking', null, ${asProvider})`)
  return rows[0]
}

async function seedPeople(db) {
  const uid = { customer: crypto.randomUUID(), provider: crypto.randomUUID() }
  await db.exec(`
    insert into auth.users (id, email) values
      ('${uid.customer}', 'c@test.ye'), ('${uid.provider}', 'p@test.ye');
    insert into public.app_users (auth_user_id, full_name, email, status)
      values ('${uid.customer}', 'أيمن محمد', 'c@test.ye', 'active'),
             ('${uid.provider}', 'صاحب القاعة', 'p@test.ye', 'active');
  `)
  // **ومقدّمُ الخدمة يُوصَل بحسابه عبر `app_users` لا بـ`auth` مباشرةً** —
  // وهي الوصلةُ التي تقرأها `current_provider()`.
  await db.exec(`
    insert into public.service_providers
      (user_id, full_name, business_name, email, status, verified_at)
      select id, 'صاحب القاعة', 'قاعة التاج', 'p2@test.ye', 'verified', now()
      from public.app_users where auth_user_id = '${uid.provider}';
  `)
  return uid
}

const count = async (db, sql) => Number((await db.query(sql)).rows[0].n)

test('**وتحقُّقُ الملفِّ يقول إنّ المفتاحين أُصلحا**', async () => {
  // **ولا يُسأل الجدولُ عن وجوده بل المفتاحُ عن فعله.** كان التحقّقُ في ذيل
  // `support.sql` يعدّ الجداولَ وطرقَ العرض والدوالّ فيقول «٢ و١ و٤» — وهو
  // لا يمسّ ما جاء الملفُّ ليُصلحه. فقد يُقرأ التقريرُ سليماً و«حذف حسابي»
  // محبوسٌ كما كان.
  //
  // **ويُنتزع التحقّقُ من الملفّ نفسِه لا يُكتب هنا نسخةً منه:** نسخةٌ في
  // الاختبار تبقى خضراءَ وإن حُذف السطرُ من الملفّ — فيُقرأ ما يُشحن.
  const sql = read('support.sql')
  const verify = sql.slice(sql.lastIndexOf('commit;') + 'commit;'.length)
  assert.ok(verify.includes('confdeltype'),
    'تحقّقُ الملفّ لا يسأل عن فعل المفتاح — فتقريرُه يُطمئن ولا يقيس')

  const db = await fresh({ files: ['install.sql', 'support.sql'] })
  const { rows } = await db.query(verify)
  const line = rows.find((r) => String(r.البند).includes('cascade'))
  assert.equal(line?.القيمة, '2', `التقريرُ يقول ${line?.القيمة} لا ٢`)
  await db.close()
})

test('**العميلُ صاحبُ التذكرة يُحذف حسابُه — وتذهب معه**', async () => {
  const db = await fresh({ files: ['install.sql', 'support.sql'] })
  const uid = await seedPeople(db)
  const t = await openTicket(db, uid.customer)

  assert.equal(await count(db, `select count(*)::int n from public.support_messages
                                 where ticket_id = '${t.id}'`), 1)

  // **ورحلةُ «حذف حسابي» كما هي:** يُحذف صفُّ `auth.users` فيتتابع الحذفُ
  // إلى `app_users` ومنها إلى التذكرة. وهذا هو ما كان يسقط.
  await db.query(`delete from auth.users where id = '${uid.customer}'`)

  assert.equal(await count(db, `select count(*)::int n from public.app_users`), 1,
    'لم يُحذف المستخدم')
  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 0,
    'بقيت التذكرةُ بلا صاحب')
  assert.equal(await count(db, `select count(*)::int n from public.support_messages`), 0,
    '**بقيت رسائلُها** — تذكرةٌ ذهبت ومتنُها باقٍ')
  await db.close()
})

test('**ومقدّمُ الخدمة كذلك**', async () => {
  // الوجهُ الآخرُ للقيد نفسِه، ويسقط بالسقوط نفسِه.
  const db = await fresh({ files: ['install.sql', 'support.sql'] })
  const uid = await seedPeople(db)
  await openTicket(db, uid.provider, { asProvider: true })

  const { rows: p } = await db.query(`select id from public.service_providers limit 1`)
  await db.query(`delete from public.service_providers where id = '${p[0].id}'`)

  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 0)
  await db.close()
})

test('**ولا يُحذف ما لصاحبه حسابٌ قائم**', async () => {
  // **وهذا ما يمنع «الإصلاح» من أن يصير مجرفة.** لو حُذف كلُّ شيءٍ لَمرّ
  // الاختبارُ الأوّلُ وسقط الدعمُ كلُّه.
  const db = await fresh({ files: ['install.sql', 'support.sql'] })
  const uid = await seedPeople(db)
  await openTicket(db, uid.customer)
  await openTicket(db, uid.provider, { asProvider: true })

  await db.query(`delete from auth.users where id = '${uid.customer}'`)

  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 1,
    'ذهبت تذكرةُ مَن لم يُحذف')
  const { rows } = await db.query(`select provider_name from public.support_tickets`)
  assert.equal(rows[0].provider_name, 'قاعة التاج')
  await db.close()
})

test('**والبيانةُ تُمسح وفيها تذاكرُ حقيقيّة**', async () => {
  // **وهذه هي الصورةُ التي أرسلها بعينها:** `seed.sql` على قاعدةٍ فيها
  // تذكرةٌ مفتوحةٌ من مستخدمٍ حقيقيّ. سقطت بـ 23514.
  const db = await fresh({ files: ['install.sql', 'support.sql'] })
  const uid = await seedPeople(db)
  await openTicket(db, uid.customer)

  await db.exec(read('seed.sql'))

  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 0)
  assert.ok(await count(db, `select count(*)::int n from public.app_users`) > 0,
    'لم تُولَّد البيانة')
  await db.close()
})

test('**وتُمسح على قاعدةٍ لا دعمَ فيها أصلاً**', async () => {
  // `support.sql` ملحقٌ يُنفَّذ على حدة. وحذفٌ صريحٌ بلا سؤالٍ عن الوجود
  // يُسقط البيانةَ كلَّها على قاعدةٍ سليمة.
  const db = await fresh({ files: ['install.sql'] })
  await db.exec(read('seed.sql'))
  assert.ok(await count(db, `select count(*)::int n from public.app_users`) > 0)
  await db.close()
})

test('**وقاعدةٌ أُنشئت قبل الإصلاح تُصلَح بإعادة الملفّ**', async () => {
  // **وهذا أهمُّ ما هنا لمشروعه القائم.** `create table if not exists` لا
  // تمسّ جدولاً موجوداً — فلولا كتلةُ الإصلاح لَبقي التضادُّ في قاعدته وإن
  // أعاد تنفيذ الملفّ مئةَ مرّة.
  const db = await fresh({ files: ['install.sql', 'support.sql'] })

  // تُعاد القاعدةُ إلى حالها القديمة: `set null` تحت قيدٍ يمنع الفراغ.
  // **والمفتاحان كلاهما** — إصلاحُ أحدِهما يترك نصفَ العطل قائماً.
  await db.exec(`
    alter table public.support_tickets drop constraint support_tickets_user_id_fkey;
    alter table public.support_tickets
      add constraint support_tickets_user_id_fkey
      foreign key (user_id) references public.app_users (id) on delete set null;
    alter table public.support_tickets drop constraint support_tickets_provider_id_fkey;
    alter table public.support_tickets
      add constraint support_tickets_provider_id_fkey
      foreign key (provider_id) references public.service_providers (id)
      on delete set null;
  `)
  const uid = await seedPeople(db)
  await openTicket(db, uid.customer)

  await assert.rejects(
    () => db.query(`delete from auth.users where id = '${uid.customer}'`),
    /ticket_has_owner/,
    'لم يسقط الحذفُ على القاعدة القديمة — فالاختبارُ لا يقيس شيئاً')

  // ثمّ يُعاد الملفُّ كما يُعيده هو في محرّر SQL.
  await db.exec(read('support.sql'))
  await db.query(`delete from auth.users where id = '${uid.customer}'`)
  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 0,
    'لم يُصلَح مفتاحُ المستخدم')

  // **ووجهُ مقدّم الخدمة يُقاس على القاعدة القديمة أيضاً** — وإلّا مرّ
  // إصلاحٌ يتناول عموداً واحداً ويترك الآخر كما كان.
  await openTicket(db, uid.provider, { asProvider: true })
  const { rows: p } = await db.query(`select id from public.service_providers limit 1`)
  await db.query(`delete from public.service_providers where id = '${p[0].id}'`)
  assert.equal(await count(db, `select count(*)::int n from public.support_tickets`), 0,
    'لم يُصلَح مفتاحُ مقدّم الخدمة')
  await db.close()
})
