-- التحقّقُ من أنّ الأجزاء الثلاثة رُكّبت كلُّها — **جملةٌ واحدة**.
--
-- ومحرّرُ Supabase يعرض نتيجةَ آخر جملةٍ وحدَها، فما كُتب في عدّة جملٍ
-- يُخفي أوائلَه. فهذه واحدةٌ تردّ صفّاً واحداً فيه الحكم.
--
--   يُلصق ويُشغَّل بعد phone_otp_1/2/3.
select
  case when count(*) filter (where ok) = 7
       then '✅ الأجزاءُ الثلاثةُ رُكّبت — ' || count(*) filter (where ok) || ' من 7'
       else '❌ ناقص — ' || count(*) filter (where ok) || ' من 7: ' ||
            string_agg(what, ' · ') filter (where not ok)
  end as "الحكم"
from (
  select 'الجدول' as what,
         to_regclass('public.phone_otp_attempts') is not null as ok
  union all
  select 'حرزُ الجدول',
         coalesce((select k.relrowsecurity from pg_class k
                     join pg_namespace n on n.oid = k.relnamespace
                    where n.nspname = 'public'
                      and k.relname = 'phone_otp_attempts'), false)
  union all
  select 'فهرسُ الرقم',
         to_regclass('public.phone_otp_attempts_phone_time_idx') is not null
  union all
  select 'فهرسُ المستخدم',
         to_regclass('public.phone_otp_attempts_user_time_idx') is not null
  union all
  select 'دالّةُ الحدّ',
         to_regprocedure('public.otp_claim_verify(uuid, text)') is not null
  union all
  select 'دالّةُ المحو',
         to_regprocedure('public.otp_clear_attempts(uuid, text)') is not null
  union all
  -- **والأهمّ**: دالّتان منزوعتان عن المسجَّل وعن الزائر. ودالّةٌ ممنوحةٌ
  -- تُنادى من التطبيق فتُصفّر العدّاد، والحدُّ كلُّه يسقط.
  select 'نزعُ الصلاحيّات',
         not exists (
           select 1 from pg_proc p
             join pg_namespace n on n.oid = p.pronamespace
            cross join unnest(array['anon', 'authenticated']) as r(role)
            where n.nspname = 'public'
              and p.proname in ('otp_claim_verify', 'otp_clear_attempts')
              and has_function_privilege(r.role, p.oid, 'execute'))
) t;
