-- ============================================================================
--  تحقّقٌ بعد تشغيل provider_columns.sql — الصِقه في محرّر SQL واضغط Run
--
--  وكلُّ سطرٍ يجب أن يخرج «نعم ✓». وسطرٌ واحدٌ «لا ✗» يعني أنّ الملفَّ مرّ
--  ولم يفعل ما جاء له.
-- ============================================================================
with secret(name) as (
  values ('email'), ('phone'), ('total_earnings'),
         ('commission_percent'), ('rejection_reason')
)
select 1 as ت, 'محجوبٌ عن المجهول: ' || s.name as البند,
       case when has_column_privilege('anon', 'public.service_providers', s.name, 'select')
            then 'لا ✗ — ما زال مكشوفاً' else 'نعم ✓' end as النتيجة
  from secret s

union all
select 2, 'محجوبٌ عن المسجَّل: ' || s.name,
       case when has_column_privilege('authenticated', 'public.service_providers', s.name, 'select')
            then 'لا ✗ — ما زال مكشوفاً' else 'نعم ✓' end
  from secret s

union all
select 3, 'وما زال المعروضُ معروضاً: ' || c.name,
       case when has_column_privilege('anon', 'public.service_providers', c.name, 'select')
            then 'نعم ✓' else 'لا ✗ — حُجب ما لا يُحجَب' end
  from (values ('business_name'), ('rating'), ('governorate'), ('status')) as c(name)

union all
select 4, 'بابُ صاحب الملفّ: api_my_provider()',
       case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                          where n.nspname = 'public' and p.proname = 'api_my_provider')
            then 'نعم ✓' else 'لا ✗ — شاشةُ المزوّد بلا أرباح' end

union all
select 5, 'وهي ممنوحةٌ للمسجَّلين لا للمجهول',
       case when has_function_privilege('authenticated', 'public.api_my_provider()', 'execute')
             and not has_function_privilege('anon', 'public.api_my_provider()', 'execute')
            then 'نعم ✓' else 'لا ✗' end

union all
select 6, 'بابُ اللوحة: v_admin_providers فيها حارسُها',
       case when (select pg_get_viewdef(c.oid) from pg_class c
                    join pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relname = 'v_admin_providers')
                 like '%is_admin()%'
            then 'نعم ✓' else 'لا ✗ — بابٌ خلفيٌّ مفتوح' end

union all
select 7, 'والدليلُ العامُّ يعمل: عددُ المزوّدين في v_providers',
       (select count(*)::text from public.v_providers)

order by ت, البند;
