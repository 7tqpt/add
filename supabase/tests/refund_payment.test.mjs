// **ردُّ المبلغ يُقيَّد في الحجز لا في الدفعة وحدَها.**
//
// ── لماذا هذا الملفّ ────────────────────────────────────────────────────────
//
// زرُّ «ردُّ المبلغ» في اللوحة كان يكتب في جدول المدفوعات مباشرةً — بخلاف
// أختيه: التأكيدُ والردُّ يمرّان بدالّة. فتصير الدفعةُ `refunded` **والحجزُ
// لا يعلم**: `refunded_amount` يبقى صفراً.
//
// **وهنا يقع الضرر.** `settlements.sql` يحسب مستحقَّ مقدّم الخدمة من
// **الحجز** لا من المدفوعات:
//
//     sum(b.paid_amount - b.refunded_amount) as gross
//
// فمن ردَّ لعميلٍ ٥٠٠٬٠٠٠ ريالٍ من اللوحة، دفعت منصّتُه للمزوّد بعدها
// ٤٥٠٬٠٠٠ كأنّ الردَّ لم يكن — **بلا أثرٍ ولا تنبيه**.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **لا حالُ الصفّ بل المالُ الخارج.** سؤالُ «أصارت الدفعةُ refunded؟» كان
// يمرّ على العطل كلِّه — فقد كانت تصير. فيُبنى المستحقُّ فعلاً ويُقاس رقمُه.
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

const ADMIN = '11111111-1111-1111-1111-111111111111'
const CUST = '22222222-2222-2222-2222-222222222222'

async function boot() {
  const db = new PGlite()
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
  // **و`roles.sql` قبل التسويات:** منها `can_write_area('finance')` التي
  // يقف عليها احتسابُ المستحقّات.
  for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                   'settlements.sql', 'payments_app.sql']) {
    await db.exec(read(f))
  }

  await db.exec(`
    insert into auth.users (id, email) values
      ('${ADMIN}', 'admin@sdd.company'), ('${CUST}', 'c@sdd.company')
      on conflict (id) do nothing;
    insert into public.admins (user_id, email, role)
      values ('${ADMIN}', 'admin@sdd.company', 'owner')
      on conflict do nothing;
  `)
  return db
}

const rows = async (db, q, p) => (await db.query(q, p)).rows
const asAdmin = (db) =>
  db.exec(`set role authenticated; select set_config('test.uid', '${ADMIN}', false);`)

/** حجزٌ منفَّذٌ مدفوعٌ بالكامل، وله دفعةٌ ناجحة — كحالِ ما يُردّ فعلاً. */
async function paidBooking(db, { price = 500000, commission = 50000 } = {}) {
  await db.exec(`reset role`)
  const [customer] = await rows(db, `select id from public.app_users order by email limit 1`)
  await db.exec(`update public.app_users set auth_user_id = '${CUST}' where id = '${customer.id}'`)

  const [bk] = await rows(db, `
    update public.bookings
       set user_id = $1, status = 'completed', completed_at = now(), cancelled_at = null,
           total_price = $2, deposit_amount = $2, paid_amount = $2, refunded_amount = 0,
           commission_amount = $3, event_date = current_date - 10
     where id = (select id from public.bookings order by reference limit 1)
    returning *`, [customer.id, price, commission])

  const [pay] = await rows(db, `
    insert into public.payments
      (reference, user_id, user_name, provider_id, provider_name, booking_id,
       booking_reference, kind, description, amount, platform_share, net_amount,
       method, status)
    values ('TRX-REF-1', $1, 'عميل', $2, 'مزوّد', $3, $4, 'deposit', 'عربون',
            $5::numeric, $6::numeric, $5::numeric - $6::numeric, 'jawali', 'paid')
    returning *`,
    [customer.id, bk.provider_id, bk.id, bk.reference, price, commission])

  return { booking: bk, payment: pay }
}

const owedFor = async (db, providerId) => {
  const [r] = await rows(db, `
    select coalesce(sum(s.net_amount), 0)::numeric n from public.settlements s
     where s.provider_id = $1`, [providerId])
  return Number(r.n)
}

test('**الردُّ يُنقص مستحقَّ المزوّد — وكان لا يمسّه**', async () => {
  const db = await boot()
  const { booking, payment } = await paidBooking(db)
  await asAdmin(db)

  await db.query(`select public.api_admin_refund_payment($1, 'العميل ألغى')`, [payment.id])

  await db.exec(`reset role`)
  const [bk] = await rows(db, `select * from public.bookings where id = $1`, [booking.id])
  assert.equal(Number(bk.refunded_amount), 500000,
    'الحجزُ لا يعلم بالردّ — وهو ما يُحسب منه مستحقُّ المزوّد')

  // **ثمّ يُبنى المستحقُّ فعلاً ويُقاس رقمُه.** لا يكفي أن يتغيّر العمود:
  // المقصودُ ألّا يخرج المالُ مرّتين.
  await asAdmin(db)
  await db.query(`select public.api_admin_build_settlements(
    (current_date - 40)::date, current_date::date)`)
  await db.exec(`reset role`)

  assert.equal(await owedFor(db, booking.provider_id), 0,
    '**دُفع للمزوّد عن حجزٍ رُدَّ مالُه** — والفرقُ من جيب المنصّة')
  await db.close()
})

test('**ولولا الردُّ لَاستحقّ** — وإلّا فالاختبارُ يقيس صفراً دائماً', async () => {
  // ضابطٌ داخل الحزمة: لو كان المستحقُّ صفراً في الحالين لَمرّ الاختبارُ
  // الأوّلُ على شيفرةٍ لا تفعل شيئاً.
  const db = await boot()
  const { booking } = await paidBooking(db)
  await asAdmin(db)
  await db.query(`select public.api_admin_build_settlements(
    (current_date - 40)::date, current_date::date)`)
  await db.exec(`reset role`)

  assert.equal(await owedFor(db, booking.provider_id), 450000,
    'لم يستحقَّ المزوّدُ شيئاً ولم يُردّ مال')
  await db.close()
})

test('**ولا يُردُّ مبلغٌ مرّتين**', async () => {
  // مسؤولان يضغطان معاً: الثاني يقف، ولا يُخصم المبلغُ من الحجز مرّتين.
  const db = await boot()
  const { booking, payment } = await paidBooking(db)
  await asAdmin(db)

  await db.query(`select public.api_admin_refund_payment($1)`, [payment.id])
  await assert.rejects(
    () => db.query(`select public.api_admin_refund_payment($1)`, [payment.id]),
    /رُدّت من قبل/)

  await db.exec(`reset role`)
  const [bk] = await rows(db, `select refunded_amount from public.bookings where id = $1`,
    [booking.id])
  assert.equal(Number(bk.refunded_amount), 500000, 'خُصم المبلغُ مرّتين')
  await db.close()
})

test('**والعميلُ يُخبَر أنّ مالَه رُدَّ**', async () => {
  const db = await boot()
  const { booking, payment } = await paidBooking(db)
  await asAdmin(db)
  await db.query(`select public.api_admin_refund_payment($1)`, [payment.id])

  await db.exec(`reset role`)
  const [n] = await rows(db, `
    select title, body from public.notifications
     where user_id = $1 and kind = 'payment'
     order by created_at desc limit 1`, [booking.user_id])
  assert.ok(n && /رُدَّ/.test(n.title), 'رُدَّ مالُه ولا يعلم')
  assert.ok(/500000/.test(n.body.replace(/[^0-9]/g, '')), `لا مبلغَ في الخبر: ${n?.body}`)
  await db.close()
})

test('**ومن لا يملك الكتابةَ لا يردّ**', async () => {
  // **ولا يُسأل الزرُّ في اللوحة بل الخادم.** حزمةٌ مفكوكةٌ تستدعي الدالّة
  // مباشرةً، فالحارسُ يجب أن يكون هنا.
  const db = await boot()
  const { payment } = await paidBooking(db)
  const viewer = '33333333-3333-3333-3333-333333333333'
  await db.exec(`
    insert into auth.users (id, email) values ('${viewer}', 'v@sdd.company');
    insert into public.admins (user_id, email, role)
      values ('${viewer}', 'v@sdd.company', 'viewer');
    set role authenticated;
    select set_config('test.uid', '${viewer}', false);`)

  await assert.rejects(
    () => db.query(`select public.api_admin_refund_payment($1)`, [payment.id]),
    /صلاحية/)
  await db.close()
})

test('**وحالُ التسوية تُقال قبل الردّ لا بعده**', async () => {
  // التنبيهُ يُقرأ قبل الضغط. ومن علم بعد وقوع الفعل لم يُنبَّه — أُخبر.
  const db = await boot()
  const { booking, payment } = await paidBooking(db)
  await asAdmin(db)

  let [r] = await rows(db, `select public.api_refund_outlook($1) as o`, [payment.id])
  assert.equal(r.o.settlement, 'none')
  assert.equal(r.o.refundable, true)

  await db.query(`select public.api_admin_build_settlements(
    (current_date - 40)::date, current_date::date)`)
  ;[r] = await rows(db, `select public.api_refund_outlook($1) as o`, [payment.id])
  assert.equal(r.o.settlement, 'pending', 'سُوّي المستحقُّ ولا يُقال')

  await db.exec(`reset role`)
  await db.exec(`update public.settlements set status = 'paid', paid_at = now()
                  where provider_id = '${booking.provider_id}'`)
  await asAdmin(db)
  ;[r] = await rows(db, `select public.api_refund_outlook($1) as o`, [payment.id])
  assert.equal(r.o.settlement, 'paid',
    '**دُفع للمزوّد ولا يُقال** — والمسؤولُ يردّ وهو يحسب أنّ المال ما زال عنده')
  await db.close()
})

test('**ويمضي الردُّ على المدفوع ولا يُحبَس**', async () => {
  // **وهذا اختيارُ صاحب المنصّة نصّاً: يمضي ويُنبَّه.** فحبسُ الردّ يمنع
  // حقّاً قد يكون واجباً للعميل.
  const db = await boot()
  const { booking, payment } = await paidBooking(db)
  await asAdmin(db)
  await db.query(`select public.api_admin_build_settlements(
    (current_date - 40)::date, current_date::date)`)
  await db.exec(`reset role`)
  await db.exec(`update public.settlements set status = 'paid', paid_at = now()
                  where provider_id = '${booking.provider_id}'`)
  await asAdmin(db)

  const [r] = await rows(db,
    `select public.api_admin_refund_payment($1) as o`, [payment.id])
  assert.equal(r.o.settlement, 'paid', 'لا يُقال للمسؤول أين ذهب المال')
  assert.equal(Number(r.o.refunded_amount), 500000)
  await db.close()
})
