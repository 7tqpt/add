-- التحقّقُ من تركيب غلاف الحجز — **جملةٌ واحدة**.
--
-- ومحرّرُ Supabase يعرض نتيجةَ آخر جملةٍ وحدَها، فما كُتب في عدّة جملٍ
-- يُخفي أوائلَه. فهذه واحدةٌ تردّ صفّاً واحداً فيه الحكم.
--
--   يُلصق ويُشغَّل بعد booking_cover.sql.
select
  case when count(*) filter (where ok) = 5
       then '✅ غلافُ الحجز مركَّبٌ — 5 من 5'
       else '❌ ناقص — ' || count(*) filter (where ok) || ' من 5: ' ||
            string_agg(what, ' · ') filter (where not ok)
  end as "الحكم"
from (
  select 'الطريقة' as what,
         to_regclass('public.v_my_bookings') is not null as ok
  union all
  select 'عمود الغلاف',
         exists (select 1 from information_schema.columns
                  where table_schema = 'public'
                    and table_name = 'v_my_bookings'
                    and column_name = 'cover_path')
  union all
  -- **ولا عمودَ من الجدول ناقص**: `Booking.fromMap` تقرأ أسماءً بأعيانها،
  -- ونقصُ عمودٍ يُسقط بطاقةً لا يُنقص صورة.
  select 'أعمدة الجدول كاملة',
         not exists (
           select 1 from information_schema.columns t
            where t.table_schema = 'public' and t.table_name = 'bookings'
              and not exists (
                select 1 from information_schema.columns v
                 where v.table_schema = 'public'
                   and v.table_name = 'v_my_bookings'
                   and v.column_name = t.column_name))
  union all
  -- **وهذا أخطرُ ما فيها**: طريقةٌ بلا `security_invoker` تعمل بصلاحيّة
  -- مالكها فتتجاوز سياسةَ `bookings` — فيُقرأ منها حجزُ كلّ أحد.
  select 'تعمل بصلاحيّة قارئها',
         coalesce(
           (select 'security_invoker=true' = any(c.reloptions)
              from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and c.relname = 'v_my_bookings'),
           false)
  union all
  -- **وبـ`to_regclass` لا باسمٍ نصّيّ**: اسمٌ لطريقةٍ غيرِ موجودةٍ يرمي
  -- `42P01` فيسقط الفحصُ كلُّه بدل أن يقول «ناقص».
  select 'ممنوعةٌ عن الزائر',
         not coalesce(
           has_table_privilege(
             'anon', to_regclass('public.v_my_bookings'), 'select'), false)
) t;
