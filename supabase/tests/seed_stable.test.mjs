// **البيانةُ الأوّليّةُ تُحسب ولا تُسحب.**
//
// ── لماذا هذا الملفّ ────────────────────────────────────────────────────────
//
// كان `seed.sql` يعتمد على `gen_random_uuid()` في مفاتيح الجداول، ثمّ يقسّم
// كلَّ شيءٍ بعد ذلك بـ`hashtext(id)`: من يأخذ خطّةَ عرسٍ، وأيُّ خدمةٍ تُحجز،
// وما حالُ الحجز. فكانت القاعدةُ تُبنى بناءً مختلفاً في كلّ تشغيل: قِستُ
// اثنتي عشرة مرّةً فخرجت الحجوزاتُ بين ٥٤ و١٠٢.
//
// **وأثرُه لم يكن نظريّاً.** `api.test.mjs` يسأل «أيرى المسؤولُ كلَّ
// الحجوزات؟» بـ`n > 50`، فمرّ عندي بـ٨٨ وسقط في CI بـ٤٦ — على الشيفرة
// نفسِها. ومن رأى ذلك ظنّ العطلَ في الحارس، والعطلُ في الأرض التي يقف
// عليها.
//
// **وكلُّ عددٍ يُقاس في ٥٤ حزمةً يقف على هذه الأرض.** فما لم تكن البيانةُ
// واحدةً في كلّ تشغيل، فكلُّ قياسٍ عليها قرعةٌ تُسحب مرّةً في المئة.
//
// ── وكيف يُقاس ──────────────────────────────────────────────────────────────
//
// تُبنى القاعدةُ مرّتين في عمليّتين مستقلّتين، وتُبصَم كلُّ مرّةٍ بصمةً
// تشمل **ما في الصفوف لا عددَها وحده**: العددُ قد يتطابق والمحتوى مختلف.
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

// الجداولُ المولّدة، وما يُبصَم من كلٍّ منها. والأعمدةُ المختارةُ هي ما
// اشتُقَّ من المفتاح المسحوب: الحالةُ والسعرُ والمرجع.
const FINGERPRINT = {
  app_users: `email || ':' || full_name || ':' || status`,
  service_providers: `email || ':' || business_name || ':' || status`,
  provider_services: `title || ':' || price::text || ':' || is_active::text`,
  wedding_plans: `title || ':' || guests_count::text || ':' || budget::text`,
  bookings: `reference || ':' || status || ':' || total_price::text || ':' || service_title`,
  payments: `reference || ':' || kind || ':' || amount::text || ':' || method`,
  reviews: `rating::text || ':' || status`,
  disputes: `reference || ':' || category || ':' || status`,
  settlements: `reference || ':' || gross_amount::text || ':' || status`,
  // **ويُبصَم القسمُ باسمه لا بمفتاحه.** مفتاحُ القسم مسحوبٌ في كلّ تشغيل
  // فلا يُقارن، وحذفُه من البصمة يترك اختيارَ القسم بلا قياس — وقد وقع:
  // كُسر ترتيبُ اختيار قسم الإعلان فبقيت الحزمةُ خضراء.
  promotions:
    `kind || ':' || placement || ':' || amount::text || ':' || status || ':' ||
     coalesce((select sc.slug from public.service_categories sc
               where sc.id = t0.category_id), '—')`,
  provider_subscriptions: `plan_name || ':' || amount::text || ':' || status`,
  conversations: `user_name || ':' || provider_name`,
}

async function build() {
  const db = new PGlite()
  await db.exec(`
    create schema auth;
    create table auth.users (id uuid primary key, email text);
    create or replace function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.uid', true), '')::uuid;
    $$;
    do $$ begin
      if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
      if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
    end $$;
  `)
  for (const f of ['schema.sql', 'policies.sql', 'api.sql', 'seed.sql']) await db.exec(read(f))

  const out = {}
  for (const [table, expr] of Object.entries(FINGERPRINT)) {
    const { rows } = await db.query(
      `select count(*)::int n,
              coalesce(md5(string_agg(f, '|' order by f)), '—') h
       from (select ${expr} as f from public.${table} t0) t`)
    out[table] = `${rows[0].n}×${rows[0].h}`
  }
  await db.close()
  return out
}

test('البيانةُ الأوّليّةُ تخرج واحدةً في كلّ تشغيل', async () => {
  const first = await build()
  const second = await build()

  for (const table of Object.keys(FINGERPRINT)) {
    const [n] = first[table].split('×')
    assert.equal(second[table], first[table],
      `${table}: تبدّل ما فيه بين تشغيلين — البيانةُ مسحوبةٌ لا محسوبة`)
    console.log(`# ✅ ${table} — ${n} صفّاً، بصمةٌ واحدة`)
  }
})

test('**ولا جدولَ يخرج فارغاً**', async () => {
  // بصمتان متطابقتان على لا شيءٍ تطابقٌ كاذب: لو انكسر التوليدُ كلُّه
  // لَخرجت البصمتان «0×—» وتساوتا.
  const one = await build()
  for (const [table, v] of Object.entries(one)) {
    const n = Number(v.split('×')[0])
    assert.ok(n > 0, `${table}: فارغ`)
  }
})

test('**والعددُ معلومٌ لا مقدَّر**', async () => {
  // **ويُكتب العددُ نصّاً.** الحزمُ تقيس بعتباتٍ كـ`n > 50`، وعتبةٌ فوق
  // بيانةٍ ثابتةٍ إمّا تمرّ أبداً أو تسقط أبداً — فيُكتب هنا ما هو كائن،
  // ومن غيّر البيانةَ عمداً يغيّر السطرَ ويرى أثرَ تغييره على الحزم.
  const one = await build()
  const counts = Object.fromEntries(
    Object.entries(one).map(([k, v]) => [k, Number(v.split('×')[0])]))

  assert.deepEqual(counts, {
    app_users: 90,
    service_providers: 44,
    provider_services: 129,
    wedding_plans: 26,
    bookings: 78,
    payments: 123,
    reviews: 8,
    disputes: 8,
    settlements: 11,
    promotions: 7,
    provider_subscriptions: 33,
    conversations: 20,
  })
})
