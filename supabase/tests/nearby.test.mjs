/**
 * الأقربُ إليك: نقطةُ مقدّم الخدمة، والترتيبُ بالمسافة.
 *
 * وأهمُّ ما يُقاس هنا أربعة:
 *
 *   ١. **أنّ المسافةَ صحيحةٌ لا معقولةٌ فحسب** — تُقاس بين مدينتين يمنيّتين
 *      معروفتَي البُعد، فلو انقلبت `radians` أو نُسي نصفُ القطر لظهر الخطأ.
 *   ٢. **وأنّ الأقربَ يسبق** — وهو كلُّ الغرض: من في عدن لا يريد قاعةً في صنعاء.
 *   ٣. **وأنّ من لا نقطةَ له يظهر آخراً لا يختفي** — إخفاؤه عقوبةٌ للعميل.
 *   ٤. **وأنّ أعمدةَ الوسائط لم تسقط** — هذا الملفّ يعيد بناء `v_services`
 *      كاملةً، وأيُّ عمودٍ ينساه يسقط صامتاً: البطاقاتُ تفقد صورَها ولا
 *      يُرمى خطأ. وهو الفخُّ نفسه الموثَّق في `api.sql`.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

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
  create role anon; create role authenticated;
`)
// **والترتيبُ مقصود:** `service_media.sql` يبني `v_services` بأعمدة الوسائط،
// ثمّ يأتي `nearby.sql` بعده — وهو الوضعُ الذي يقع عند المالك.
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'service_media.sql', 'availability.sql',
                 'settlements.sql', 'profile.sql', 'profile_extras.sql',
                 'coupons.sql', 'location.sql']) {
  await db.exec(read(f))
}
const file = read('nearby.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]
const raises = async (q, p) => {
  try { await db.query(q, p); return null } catch (e) { return e.message }
}

// نقاطٌ حقيقيّة — لا أصفارٌ ولا أرقامٌ مخترعة.
const SANAA = { lat: 15.354722, lng: 44.206667 }
const ADEN = { lat: 12.788440, lng: 45.036560 }
const TAIZ = { lat: 13.578300, lng: 44.017700 }

// ── ١. **المسافةُ رقمٌ يُصدَّق** ────────────────────────────────────────────
//
// وصنعاءُ وعدنُ بينهما نحو ٣٠٠ كم في خطٍّ مستقيم — والطريقُ بينهما أطولُ من
// ذلك بكثير، وهذا ما يخلط. والمقيسُ هنا خطُّ الطائر لا خطُّ السيّارة.
//
// والمجالُ ضيّقٌ عمداً: خطأُ `radians` أو نصفِ القطر يقفز بالرقم أضعافاً أو
// يهبط به إلى الكسور، فلا يمرّ من عشرين كيلومتراً.
const d = Number((await one(
  `select public.distance_km($1, $2, $3, $4) as كم`,
  [SANAA.lat, SANAA.lng, ADEN.lat, ADEN.lng])).كم)
ok('صنعاء وعدن بينهما نحو ٣٠٠ كم', d > 290 && d < 310, `${d} كم`)

// وتعزُّ وعدنُ بينهما نحو ١٤٠ — نقطةٌ ثالثةٌ تمنع أن يكون الصوابُ مصادفةً في
// اتّجاهٍ واحد.
const dAdenTaiz = Number((await one(
  `select public.distance_km($1, $2, $3, $4) as كم`,
  [ADEN.lat, ADEN.lng, TAIZ.lat, TAIZ.lng])).كم)
ok('وعدن وتعزّ بينهما نحو ١٤٠ كم', dAdenTaiz > 130 && dAdenTaiz < 150,
   `${dAdenTaiz} كم`)

const zero = Number((await one(
  `select public.distance_km($1, $2, $1, $2) as كم`, [SANAA.lat, SANAA.lng])).كم)
ok('والنقطةُ من نفسها صفر', zero === 0)

ok('والمسافةُ من نقطةٍ ناقصةٍ NULL لا صفر',
   (await one(`select public.distance_km($1, $2, null, null) as كم`,
              [SANAA.lat, SANAA.lng])).كم === null)

// وترتيبُ الأقربِ يعتمد على أنّ الأبعدَ أبعد — لا على قيمةٍ بعينها.
const dTaiz = Number((await one(
  `select public.distance_km($1, $2, $3, $4) as كم`,
  [SANAA.lat, SANAA.lng, TAIZ.lat, TAIZ.lng])).كم)
ok('وتعزُّ أقربُ إلى صنعاء من عدن', dTaiz < d, `${dTaiz} كم مقابل ${d}`)

// ── ٢. نقطةُ المزوّد: كاملةٌ أو لا شيء ──────────────────────────────────────
const provs = await rows(`
  select id, business_name from public.service_providers
   where status = 'verified' order by created_at limit 3`)
ok('تجهيزٌ: ثلاثةُ مزوّدين موثَّقين', provs.length === 3)

const [near, far, blank] = provs
await db.query(
  `update public.service_providers set latitude = $2, longitude = $3 where id = $1`,
  [near.id, SANAA.lat, SANAA.lng])
await db.query(
  `update public.service_providers set latitude = $2, longitude = $3 where id = $1`,
  [far.id, ADEN.lat, ADEN.lng])

ok('ونصفُ نقطةٍ في ملفّ المزوّد يُردّ',
   /provider_point_sane|violates check/i.test(
     (await raises(
       `update public.service_providers set latitude = 15.3, longitude = null
         where id = $1`, [blank.id])) ?? ''))

ok('وخطُّ طولٍ خارج المدى يُردّ',
   /provider_point_sane|violates check/i.test(
     (await raises(
       `update public.service_providers set latitude = 15.3, longitude = 181
         where id = $1`, [blank.id])) ?? ''))

// ── ٣. **أعمدةُ الوسائط لم تسقط من الطريقة** ────────────────────────────────
//
// وهذا هو الفخُّ: `nearby.sql` يبني `v_services` من أوّلها، فلو نسي عموداً
// أضافه `service_media.sql` لَما رُمي خطأٌ — البطاقاتُ تفقد صورَها فحسب.
const cols = (await rows(`
  select column_name from information_schema.columns
   where table_schema = 'public' and table_name = 'v_services'`))
  .map((r) => r.column_name)
for (const c of ['cover_path', 'images_count', 'has_video', 'has_audio']) {
  ok(`وعمودُ ${c} باقٍ في v_services`, cols.includes(c))
}
for (const c of ['provider_latitude', 'provider_longitude']) {
  ok(`وعمودُ ${c} أُضيف`, cols.includes(c))
}
ok('والغلافُ يُقرأ فعلاً لا اسماً',
   (await one(`select count(*)::int as ع from public.v_services`)).ع > 0)

// ── ٤. **والأقربُ يسبق** ────────────────────────────────────────────────────
//
// وهو كلُّ الغرض. ولو سقط سطرُ `distance_km` من `order by` لَبقي الترتيبُ
// بالتمييز والتقييم — ولَمرّ هذا الاختبارُ لو صادف أنّ الأقربَ هو المميَّز.
//
// **فيُبنى التجهيزُ ضدَّ الشيفرة عمداً:** المميَّزُ الأعلى تقييماً هو
// **البعيدُ** ومَن **لا نقطةَ له**، والقريبُ أدناهم تمييزاً وتقييماً. فلا
// يسبق القريبُ إلّا بالمسافة وحدها، ولا يتأخّر عديمُ النقطة إلّا لأنّه
// بلا نقطة.
//
// والتمييزُ والتقييمُ يحرسهما `guard_provider_self_update` — فلا يكتبهما إلّا
// المسؤولُ أو دالّةٌ داخليّة. وهذا صوابٌ في القاعدة، فيُرفع العلمُ هنا كما
// ترفعه الدوالُّ الداخليّة، لا يُعطَّل الحارس.
await db.exec(`select set_config('app.internal', 'on', false)`)
await db.query(
  `update public.service_providers set is_featured = true, rating = 5.0 where id = $1`,
  [far.id])
await db.query(
  `update public.service_providers set is_featured = true, rating = 4.9 where id = $1`,
  [blank.id])
await db.query(
  `update public.service_providers set is_featured = false, rating = 3.0 where id = $1`,
  [near.id])
await db.exec(`select set_config('app.internal', 'off', false)`)

const order = await rows(
  `select id, business_name, latitude, longitude
     from public.api_providers_nearby($1, $2, null, '', 50)`,
  [SANAA.lat, SANAA.lng])
ok('من في صنعاء يجد الصنعانيَّ أوّلاً وإن كان الآخرُ مميَّزاً',
   order[0]?.id === near.id,
   `الأوّل: ${order[0]?.business_name}`)

// ومن في عدن ينعكس عليه الترتيب — وهذا ما يمنع «الأوّلُ أوّلٌ دائماً».
const fromAden = await rows(
  `select id from public.api_providers_nearby($1, $2, null, '', 50)`,
  [ADEN.lat, ADEN.lng])
ok('ومن في عدن يجد العدنيَّ أوّلاً', fromAden[0]?.id === far.id)

// ── ٥. **ومن لا نقطةَ له يظهر آخراً لا يختفي** ──────────────────────────────
const ids = order.map((r) => r.id)
ok('والمزوّدُ بلا نقطةٍ موجودٌ في النتائج', ids.includes(blank.id))
ok('وهو بعد صاحبَي النقطة',
   ids.indexOf(blank.id) > ids.indexOf(near.id) &&
   ids.indexOf(blank.id) > ids.indexOf(far.id))

// وكلُّ من بلا نقطةٍ في الذيل: لا واحدٌ يتسلّل بينهم.
const firstBlank = order.findIndex((r) => r.latitude === null)
ok('وأصحابُ النقاط كلُّهم قبل من لا نقطةَ له',
   order.slice(firstBlank).every((r) => r.latitude === null))

// ── ٦. الخدمات: الترتيبُ نفسه، والترشيحُ باقٍ ───────────────────────────────
const svcNear = await rows(
  `select id, provider_id, category_id, title, cover_path
     from public.api_services_nearby($1, $2, null, '', 60)`,
  [SANAA.lat, SANAA.lng])
ok('وخدماتُ الأقربِ تسبق', svcNear[0]?.provider_id === near.id,
   svcNear[0]?.provider_id === near.id ? '' :
   svcNear[0]?.provider_id === far.id ? 'الأولى للبعيد' : 'الأولى لثالثٍ')
ok('والغلافُ يعود مع الصفّ', 'cover_path' in (svcNear[0] ?? {}))

// والترشيحُ بالقسم لم يُلغَ بالترتيب الجديد.
const cat = await one(`
  select category_id from public.provider_services
   where provider_id = $1 and is_active limit 1`, [near.id])
const inCat = await rows(
  `select category_id from public.api_services_nearby($1, $2, $3, '', 60)`,
  [SANAA.lat, SANAA.lng, cat.category_id])
ok('والترشيحُ بالقسم يعمل',
   inCat.length > 0 && inCat.every((r) => r.category_id === cat.category_id))

// وترشيحُ **الدليل** بالقسم مسلكٌ آخر: بالاسم لا بالمعرّف — لأنّ طريقةَ
// الدليل تحمل الأسماء، والشاشةُ ترشِّح بها اليوم. وكان بلا اختبارٍ حتى كشفه
// ضابطٌ لم يعضّ.
const pcat = (await one(`
  select c.name from public.provider_categories pc
    join public.service_categories c on c.id = pc.category_id limit 1`)).name
const provsInCat = await rows(
  `select id from public.api_providers_nearby($1, $2, $3, '', 200)`,
  [SANAA.lat, SANAA.lng, pcat])
const allInCat = await rows(`
  select id from public.v_providers where $1 = any(categories)`, [pcat])
const allProvs = await rows(`select id from public.v_providers`)
// **والقسمُ يجب أن يقتطع فعلاً:** لو ضمّ القسمُ كلَّ المزوّدين لَمرّ هذا
// الاختبارُ ولو أُلغي الترشيحُ كلُّه.
ok('تجهيزٌ: القسمُ أضيقُ من الدليل كلّه',
   allInCat.length > 0 && allInCat.length < allProvs.length,
   `${allInCat.length} من ${allProvs.length}`)
ok('وترشيحُ الدليلِ بالقسم يعمل',
   provsInCat.length === allInCat.length,
   `${provsInCat.length} من ${allInCat.length}`)
ok('ولا يُدخِل من ليس في القسم',
   provsInCat.every((r) => allInCat.some((a) => a.id === r.id)))

// والبحثُ بالنصّ كذلك — وهو يمرّ على اسم الخدمة واسم المزوّد.
const title = (await one(
  `select title from public.provider_services where is_active limit 1`)).title
const word = title.split(' ')[0]
const found = await rows(
  `select title, provider_name from public.api_services_nearby($1, $2, null, $3, 60)`,
  [SANAA.lat, SANAA.lng, word])
// **والشرطُ يشمل الاسمين:** البحثُ يمرّ على عنوان الخدمة وعلى اسم المزوّد،
// فصفٌّ يطابق بالثاني ليس خطأً. والمقيسُ أنّ **كلَّ** صفٍّ يطابق أحدَهما —
// ولو أُلغي الترشيحُ لَعادت الستّون كلُّها وسقط هذا.
ok('والبحثُ بالنصّ يعمل',
   found.length > 0 &&
   found.every((r) => r.title.includes(word) || r.provider_name.includes(word)))
ok('وكلمةٌ لا وجودَ لها تُرجع فارغاً',
   (await rows(`select title from public.api_services_nearby($1, $2, null, $3, 60)`,
               [SANAA.lat, SANAA.lng, 'زقنبوتٌ لا يوجد'])).length === 0)

// ── ٦ب. **والمحافظةُ مرشِّحٌ باقٍ** ─────────────────────────────────────────
//
// الشاشةُ فيها شريطُ محافظاتٍ ومفتاحُ «الأقرب إليّ» معاً. ولو أسقطت الطريقةُ
// المحافظةَ لَكذبت الشاشةُ على صاحبها: يختار «عدن» فتأتيه صنعاء.
const gov = (await one(`
  select provider_governorate as g from public.v_services
   where provider_governorate <> '' limit 1`)).g
const inGov = await rows(
  `select provider_governorate as g from public.api_services_nearby($1, $2, null, '', 60, $3)`,
  [SANAA.lat, SANAA.lng, gov])
const allSvc = await rows(`select id from public.v_services`)
ok('وترشيحُ الخدمات بالمحافظة يعمل',
   inGov.length > 0 && inGov.length < allSvc.length &&
   inGov.every((r) => r.g === gov),
   `${inGov.length} من ${allSvc.length}`)

const provGov = await rows(
  `select governorate as g from public.api_providers_nearby($1, $2, null, '', 60, $3)`,
  [SANAA.lat, SANAA.lng, gov])
ok('وترشيحُ الدليل بالمحافظة يعمل',
   provGov.length > 0 && provGov.every((r) => r.g === gov))

// ── ٧. الحدّ يُحترم، والفارغُ لا يصير صفَّ NULLات ───────────────────────────
//
// **وفخُّ المركَّب الفارغ:** لو كُتبت `returns public.v_services` بدل
// `returns setof`، لَعادت من لا نتائجَ لها صفّاً واحداً كلُّه NULL — بطاقةٌ
// بيضاءُ في الشاشة بدل «لا نتائج».
const limited = await rows(
  `select id from public.api_services_nearby($1, $2, null, '', 3)`,
  [SANAA.lat, SANAA.lng])
ok('والحدُّ يُحترم', limited.length === 3)

const empty = await rows(
  `select id from public.api_services_nearby($1, $2,
     '00000000-0000-0000-0000-000000000000'::uuid, '', 40)`,
  [SANAA.lat, SANAA.lng])
ok('ولا نتائجَ تعني صفراً من الصفوف لا صفّاً من NULLات', empty.length === 0)

// ── ٨. **وباحثٌ بلا نقطةٍ يعود إلى الترتيب المعتاد** ────────────────────────
//
// المسافةُ تصير NULL للجميع حين تنقص نقطةُ الباحث، فيسقط الترتيبُ إلى
// التمييز والتقييم — وهو الترتيبُ المعتاد نفسه، وهو الصواب.
//
// وكان في الشيفرة علمٌ زائدٌ `(latitude is null)` قبل المسافة، فحُذف بعد أن
// كشفه ضابطٌ: كان يهبط بمزوّدٍ **مميَّزٍ** تحت غيرِ المميَّز لأنّه لم يضع
// نقطةً على خريطةٍ لا تُقرأ في هذا النداء أصلاً.
const noPoint = await rows(
  `select id, latitude, is_featured, rating
     from public.api_providers_nearby(null, null, null, '', 50)`)
const at = (id) => noPoint.findIndex((r) => r.id === id)
ok('وباحثٌ بلا نقطةٍ يرى المميَّزَ أوّلاً', noPoint[0]?.id === far.id)
ok('**ولا يُعاقَب من لا نقطةَ له وهو مميَّز**', at(blank.id) < at(near.id),
   'العلمُ الزائدُ كان يهبط به تحت غيرِ المميَّز')

// ── ٩. والأذونات: العميلُ يقرأ، والصلاحيّةُ ليست للعامّة ────────────────────
const grants = await rows(`
  select grantee, privilege_type from information_schema.routine_privileges
   where routine_schema = 'public' and routine_name = 'api_services_nearby'`)
const grantees = grants.map((g) => g.grantee)
ok('والعميلُ يستطيع نداءها',
   grantees.includes('anon') && grantees.includes('authenticated'))
ok('ولا صلاحيّةَ للعامّة', !grantees.includes('PUBLIC'))

// وهي `security invoker`: لا تفتح ما تغلقه السياسات.
ok('وليست security definer',
   (await one(`select prosecdef from pg_proc
                where proname = 'api_services_nearby'
                  and pronamespace = 'public'::regnamespace`)).prosecdef === false)

// ── ١٠. ولا توقيعان لأيّ دالّة ──────────────────────────────────────────────
for (const f of ['api_services_nearby', 'api_providers_nearby', 'distance_km']) {
  ok(`ولا توقيعان لـ${f}`,
     (await one(`select count(*)::int as ع from pg_proc
                  where proname = $1 and pronamespace = 'public'::regnamespace`,
                [f])).ع === 1)
}

// **والحذفُ بالاسم يمسح توقيعاً قديماً لا يعرفه الملفّ.**
//
// وهذا هو الفخُّ الذي وقع في هذا المشروع مرّتين: زيادةُ معاملٍ تصنع دالّةً
// ثانيةً، فتبقى الأولى ويناديها PostgREST أحياناً. فيُصطنع هنا توقيعٌ غريب،
// ثمّ يُعاد تشغيلُ الملفّ، ويُقاس أنّه لم يبقَ.
await db.exec(`
  create function public.api_services_nearby(p_old text)
  returns setof public.v_services language sql stable as $f$
    select * from public.v_services limit 1 $f$;`)
ok('تجهيزٌ: توقيعٌ قديمٌ مصطنع',
   (await one(`select count(*)::int as ع from pg_proc
                where proname = 'api_services_nearby'
                  and pronamespace = 'public'::regnamespace`)).ع === 2)
await db.exec(file)
ok('**والحذفُ بالاسم يمسح التوقيعَ القديم**',
   (await one(`select count(*)::int as ع from pg_proc
                where proname = 'api_services_nearby'
                  and pronamespace = 'public'::regnamespace`)).ع === 1)

// ── ١١. **وما يناديه التطبيق موجودٌ فعلاً** ─────────────────────────────────
//
// `audit.test.mjs` يقرأ شيفرةَ **اللوحة** وحدها (`src/services`)، ولا يمرّ
// على تطبيق Flutter. فاسمُ طريقةٍ يُخطئ حرفاً في Dart لا يمنع بناءً ولا
// يوقظ اختباراً — يظهر يومَ يضغط عميلٌ «الأقرب إليّ» فيرى خطأً أحمر.
//
// فتُقرأ هنا أسماءُ الطرائق ومعاملاتُها من `api.dart` نفسه وتُسأل القاعدةُ
// عنها. وهذا للميزة هذه وحدها — لا يدّعي أكثر.
const dart = readFileSync(
  new URL('../../mobile/lib/src/data/api.dart', import.meta.url), 'utf8')

for (const fn of ['api_services_nearby', 'api_providers_nearby']) {
  ok(`و${fn} يناديها التطبيق`, dart.includes(`'${fn}'`))
}

const called = [...dart.matchAll(/rpc\('(api_\w*nearby)',\s*params:\s*\{([^}]*)\}/g)]
ok('تجهيزٌ: نداءان في api.dart', called.length === 2, `${called.length}`)

for (const [, fn, body] of called) {
  const sent = [...body.matchAll(/'(p_\w+)'/g)].map((m) => m[1])
  const known = (await rows(`
    select unnest(proargnames) as n from pg_proc
     where proname = $1 and pronamespace = 'public'::regnamespace`, [fn]))
    .map((r) => r.n)
  const strays = sent.filter((p) => !known.includes(p))
  ok(`ومعاملاتُ ${fn} كلُّها معروفة`, strays.length === 0, strays.join('، '))
  ok(`ونقطةُ الباحث تُرسل إلى ${fn}`,
     sent.includes('p_latitude') && sent.includes('p_longitude'))
}

// والأعمدةُ التي يقرؤها النموذج من الصفّ.
const models = readFileSync(
  new URL('../../mobile/lib/src/data/models.dart', import.meta.url), 'utf8')
ok('والنموذجُ يقرأ نقطةَ المزوّد من صفّ الخدمة',
   models.includes("'provider_latitude', 'provider_longitude'"))
for (const c of ['provider_latitude', 'provider_longitude']) {
  ok(`وعمودُ ${c} موجودٌ في القاعدة`, cols.includes(c))
}

await db.close()
console.log(fail === 0 ? '\nكل اختبارات nearby.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
