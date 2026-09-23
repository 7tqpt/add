// **ما لا يراه المجهولُ ولا المسجَّلُ — عموداً عموداً.**
//
// ── الفراغُ الذي يملؤه ─────────────────────────────────────────────────────
//
// في `tests/` ثمانيةٌ وستّون اختباراً، وفيها `rls_coverage` و`views.rls`
// و`controls_rls.sh` — **وكلُّها تسأل عن الصفوف**. و‏RLS تحجب صفوفاً لا
// أعمدة: جدولٌ مفعَّلُ الحرزِ سياستُه `using (status = 'verified')` يُخرج
// الصفَّ **كلَّه** لمن طابق شرطَها، بما فيه بريدُ صاحبه وجوّالُه وأرباحُه.
//
// ولذلك بقي `service_providers` مكشوفاً بينما `provider_availability` محروسٌ
// في الملفّ المجاور بالنمط نفسِه: الحرزُ كُتب مرّةً ولم يُقَس، فلم يُعمَّم.
//
// ── وكيف يُقاس ─────────────────────────────────────────────────────────────
//
// `has_column_privilege` تسأل القاعدةَ نفسَها: «أيقرأ `anon` هذا العمود؟»
// فتُجمع إجابتُها لكلّ عمودٍ في كلّ جدول، وتُقابل بقائمةٍ مكتوبةٍ أدناه.
//
// **ولا تسأل هذه عن سياسةٍ ولا عن نصّ SQL**: تسأل عن الصلاحية بعد أن استقرّت
// — فما التفّ عليه منحٌ في موضعٍ آخرَ ظهر هنا، وهو بالضبط ما وقع.
//
// ── وقائمتان لا واحدة ──────────────────────────────────────────────────────
//
//   `MUST_HIDE` — أعمدةٌ **يجب** أن تكون محجوبة. وهذه هي الضمانة.
//   `KNOWN`     — كلُّ عمودٍ محجوبٍ اليوم. وهي لا تحرس شيئاً وحدَها، لكنّها
//                 تُظهر في الناتج ما تغيّر: عمودٌ خرج من الحجب يُقرأ في سطرٍ
//                 واحدٍ بدل أن يُفتّش عنه.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

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
  create role anon; create role authenticated; create role service_role;`)

// **والملفّاتُ كلُّها تُشغَّل بالترتيب** — ومنها ما ينزع أعمدةً بعد أن مُنحت.
// فقراءةُ الصلاحية بعد بعضها تُعطي جواباً لا يشبه ما في القاعدة الحقيقيّة.
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'availability.sql', 'phone_verify.sql',
                 'provider_columns.sql']) {
  await db.exec(read(f))
}

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}

// ── ما يجب أن يبقى محجوباً ─────────────────────────────────────────────────
//
// وكلُّ سطرٍ هنا ثغرةٌ أُغلقت أو ضمانةٌ قائمة — لا تفضيلاً في الشكل.
const MUST_HIDE = {
  service_providers: [
    'email',              // بريدُ كلِّ مزوّدٍ موثَّق
    'phone',              // ورقمُه — وهما معاً دليلُ موردي الأعراس كلِّه
    'total_earnings',     // كم كسب من المنصّة
    'commission_percent', // عمولتُه الخاصّة إن خالفت العامّة
    'rejection_reason',   // سببُ رفضه إن رُفض ثمّ وُثّق
  ],
  provider_availability: [
    'note',               // «محجوز — BK-2026-0007»، و«سفر»، و«مناسبة عائلية»
  ],
}

const privileges = async (role) => (await db.query(`
  select c.table_name, c.column_name,
         has_column_privilege($1, 'public.' || quote_ident(c.table_name),
                              c.column_name, 'select') as readable
    from information_schema.columns c
    join pg_class  k on k.relname = c.table_name
    join pg_namespace n on n.oid = k.relnamespace and n.nspname = 'public'
   where c.table_schema = 'public' and k.relkind = 'r'
   order by c.table_name, c.ordinal_position`, [role])).rows

const anon = await privileges('anon')
const authed = await privileges('authenticated')

// ولا يُصدَّق أنّ المسحَ وقع: مسحٌ فارغٌ يُمرّر كلَّ شيء.
ok(`مُسحت أعمدةُ القاعدة (${anon.length} عموداً في ${new Set(anon.map(r => r.table_name)).size} جدولاً)`,
   anon.length > 300)

// ── ١. الممنوعُ ممنوعٌ على الاثنين ─────────────────────────────────────────
//
// **وعلى `authenticated` كذلك لا `anon` وحدَه.** من يتصفّح التطبيقَ مسجَّلٌ
// لا مجهول — فحجبٌ عن المجهول وحدَه لا يحجب شيئاً عمّن فتح حساباً في دقيقة.
for (const [table, columns] of Object.entries(MUST_HIDE)) {
  for (const column of columns) {
    for (const [role, rows] of [['anon', anon], ['authenticated', authed]]) {
      const row = rows.find((r) => r.table_name === table && r.column_name === column)
      ok(`${table}.${column} محجوبٌ عن ${role}${row ? '' : ' — لا عمودَ بهذا الاسم أصلاً!'}`,
         row !== undefined && row.readable === false)
    }
  }
}

// ── ٢. وما بقي مكشوفاً يُقرأ في سطر ────────────────────────────────────────
//
// هذه لا تُحمّر: تطبع. والقائمةُ المتوقَّعةُ مكتوبةٌ كي يظهر في الناتج ما
// زاد عنها — عمودٌ جديدٌ حُجب، أو حرزٌ سقط.
const hidden = anon.filter((r) => !r.readable)
   .map((r) => `${r.table_name}.${r.column_name}`).sort()
const KNOWN = [
  ...MUST_HIDE.service_providers.map((c) => `service_providers.${c}`),
  ...MUST_HIDE.provider_availability.map((c) => `provider_availability.${c}`),
].sort()

const extra = hidden.filter((c) => !KNOWN.includes(c))
const gone = KNOWN.filter((c) => !hidden.includes(c))
console.log(`\nالمحجوبُ عن المجهول (${hidden.length}):\n  ${hidden.join('\n  ') || '— لا شيء —'}`)
if (extra.length) console.log(`\nزائدٌ عن المعروف: ${extra.join(', ')}`)
ok(`ولا حرزَ سقط${gone.length ? `: ${gone.join(', ')}` : ''}`, gone.length === 0)

// ── ٣. وجدولُ عدّاد الرموز لا يُلمس أصلاً ──────────────────────────────────
//
// `phone_otp_sends` و`phone_otp_attempts` مفعَّلا الحرزِ بلا سياسةٍ لأحد،
// ولا يلمسهما إلّا مفتاحُ الخدمة من داخل دالّة الحدّ. وعدّادٌ يُقرأ أو يُكتب
// من التطبيق عدّادٌ يُصفَّر.
//
// **ويُسأل أوّلاً: أثَمَّ جدول؟** عدُّ سياساتِ جدولٍ معدومٍ صفرٌ كذلك — فكان
// الفحصُ يخضرّ لجدولٍ لم يُخلَق بعد، وهي ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
for (const table of ['phone_otp_sends', 'phone_otp_attempts']) {
  const exists = (await db.query(`
    select count(*)::int as n from pg_class k
      join pg_namespace n on n.oid = k.relnamespace
     where n.nspname = 'public' and k.relname = $1 and k.relkind = 'r'`, [table])).rows[0].n
  ok(`${table} موجودٌ في القاعدة`, exists === 1)
  if (exists !== 1) continue

  const rls = (await db.query(`
    select k.relrowsecurity as on from pg_class k
      join pg_namespace n on n.oid = k.relnamespace
     where n.nspname = 'public' and k.relname = $1`, [table])).rows[0].on
  ok(`${table} مفعَّلُ الحرز`, rls === true)

  const rows = (await db.query(`
    select count(*)::int as n from pg_policies
     where schemaname = 'public' and tablename = $1`, [table])).rows[0].n
  ok(`${table} بلا سياسةٍ لأحد (${rows})`, rows === 0)
}

await db.close()
process.exit(fail === 0 ? 0 : 1)
