-- تحقّق سريع: هل وصل كل شيء؟
select 'الجداول'   as البند, count(*)::text as العدد, '33' as المتوقع
  from information_schema.tables
 where table_schema = 'public' and table_type = 'BASE TABLE'
union all
select 'طرق العرض', count(*)::text, '3'
  from information_schema.views where table_schema = 'public'
union all
select 'دوال الـ API', count(*)::text, '10'
  from information_schema.routines
 where routine_schema = 'public' and routine_name like 'api\_%'
union all
select 'سياسات RLS', count(*)::text, '40+'
  from pg_policies where schemaname = 'public'
union all
select 'جداول بلا RLS (يجب أن يكون 0)', count(*)::text, '0'
  from pg_tables t
 where t.schemaname = 'public'
   and not exists (select 1 from pg_class c
                    join pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relname = t.tablename and c.relrowsecurity);
