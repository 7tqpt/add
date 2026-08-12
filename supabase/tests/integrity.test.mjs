import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'
const db = new PGlite()
// Stub what Supabase supplies: the auth schema and the anon/authenticated roles.
await db.exec(`
  create schema auth;
  create table auth.users(id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
  do $$ begin
    if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
    if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  end $$;
`)
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')
for (const f of ['schema.sql', 'policies.sql', 'api.sql', 'seed.sql']) await db.exec(read(f))

const checks = [
  ['حجز مؤكد بلا مقدّم خدمة',
   `select count(*)::int n from bookings where status<>'pending_provider' and provider_id is null`],
  ['مدفوع أكبر من الإجمالي',
   `select count(*)::int n from bookings where paid_amount > total_price`],
  ['مسترد أكبر من المدفوع',
   `select count(*)::int n from bookings where refunded_amount > paid_amount`],
  ['تقييم على حجز غير منفّذ',
   `select count(*)::int n from reviews r join bookings b on b.id=r.booking_id where b.status<>'completed'`],
  ['مدفوعات لا تطابق مجموع الحجز',
   `select count(*)::int n from (
      select b.id, b.paid_amount, coalesce(sum(p.amount) filter (where p.status='paid'),0) s
      from bookings b left join payments p on p.booking_id=b.id
      where b.status in ('confirmed','completed') group by b.id, b.paid_amount
    ) t where abs(paid_amount - s) > 0.01`],
  ['حصة المنصة + المستحق > المبلغ',
   `select count(*)::int n from payments where platform_share + net_amount > amount + 0.001`],
  ['بند تسوية لحجز غير منفّذ',
   `select count(*)::int n from settlement_items si join bookings b on b.id=si.booking_id where b.status<>'completed'`],
  ['خدمة بلا سياسة إلغاء',
   `select count(*)::int n from provider_services where cancellation_policy_id is null`],
  ['مقدّم خدمة موثّق بلا تاريخ توثيق',
   `select count(*)::int n from service_providers where status='verified' and verified_at is null`],
  ['مقدّم خدمة بلا قسم',
   `select count(*)::int n from service_providers p where not exists (select 1 from provider_categories where provider_id=p.id)`],
]

let bad = 0
for (const [label, sql] of checks) {
  const { rows } = await db.query(sql)
  const n = rows[0].n
  if (n > 0) bad++
  console.log(`${n === 0 ? '✅' : '❌'} ${label}: ${n}`)
}

// The refund helper must actually compute something sensible.
const { rows: refunds } = await db.query(`
  select b.reference, b.event_date, b.paid_amount,
         public.refundable_amount(b.id) as refundable
  from bookings b where b.status='confirmed' and b.event_date > current_date
  order by b.event_date limit 3`)
console.log('\nالمبلغ المستردّ لو أُلغي الآن:')
for (const r of refunds) {
  console.log(`   ${r.reference} · الموعد ${r.event_date.toISOString().slice(0,10)} · مدفوع ${r.paid_amount} → يُسترد ${r.refundable}`)
}

const { rows: money } = await db.query(`
  select
    (select round(sum(amount),2) from payments where status='paid') as collected,
    (select round(sum(platform_share),2) from payments where status='paid') as platform,
    (select round(sum(amount),2) from payments where status='refunded') as refunded,
    (select round(sum(net_amount),2) from settlements) as owed_to_partners`)
console.log('\nالمالية:', money[0])

await db.close()
process.exit(bad ? 1 : 0)
