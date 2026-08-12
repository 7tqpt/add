-- ============================================================================
--  تحقّق شامل — بعد install.sql و seed.sql و apply.sql و storage.sql و support.sql
--
--  الصقه في SQL Editor واضغط Run. كل سطر يقارن الواقع بالمتوقَّع، والعمود
--  الأخير يقول «سليم» أو «راجعه» فلا تحتاج أن تعدّ بنفسك.
--
--  الأرقام المتوقَّعة ليست تخميناً: حُسبت بتشغيل الملفات الخمسة على Postgres
--  حقيقي، فما تراه هنا هو ما تنتجه فعلاً.
-- ============================================================================

with checks as (

  select 1 as ord, 'الجداول' as البند,
         (select count(*) from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE') as الواقع,
         35 as المتوقع

  union all
  select 2, 'طرق العرض',
         (select count(*) from information_schema.views where table_schema = 'public'), 10

  union all
  select 3, 'دوال الـ API',
         (select count(*) from information_schema.routines
           where routine_schema = 'public' and routine_name like 'api\_%'), 13

  union all
  select 4, 'سياسات RLS',
         (select count(*) from pg_policies where schemaname = 'public'), 70

  -- الصفر هو الصواب هنا: جدول بلا RLS مكشوف لكل من يملك المفتاح العام.
  union all
  select 5, 'جداول بلا RLS',
         (select count(*) from pg_tables t
           where t.schemaname = 'public'
             and not exists (select 1 from pg_class c
                               join pg_namespace ns on ns.oid = c.relnamespace
                              where ns.nspname = 'public' and c.relname = t.tablename
                                and c.relrowsecurity)), 0

  -- طريقة عرض بلا security_invoker تعمل بصلاحيات مالكها فتلتفّ حول كل السياسات.
  union all
  select 6, 'طرق عرض بلا security_invoker',
         (select count(*) from pg_class c
            join pg_namespace ns on ns.oid = c.relnamespace
           where ns.nspname = 'public' and c.relkind = 'v'
             and coalesce(c.reloptions::text, '') not like '%security_invoker=true%'), 0

  union all
  select 7, 'الأقسام (مع الطبخ)',
         (select count(*) from public.service_categories), 12

  union all
  select 8, 'طرق عرض اللوحة',
         (select count(*) from pg_views
           where schemaname = 'public'
             and (viewname like 'v\_admin\_%' or viewname = 'v_plan_summary')), 8

  -- ---- خدمة العملاء (support.sql) ----
  union all
  select 9, 'جدولا التذاكر',
         (select count(*) from information_schema.tables
           where table_schema = 'public'
             and table_name in ('support_tickets', 'support_messages')), 2

  union all
  select 10, 'دوال التذاكر',
         (select count(*) from information_schema.routines
           where routine_schema = 'public'
             and routine_name in ('api_open_ticket', 'api_reply_ticket',
                                  'api_close_ticket', 'admin_reply_ticket')), 4

  -- ---- التخزين (storage.sql) ----
  union all
  select 11, 'حاوية المستندات (0=مفقودة)',
         (select count(*) from storage.buckets where id = 'provider-docs'), 1

  -- الصفر هو الصواب: الحاوية العامة تفتح صور الهويات لأي شخص يعرف الرابط.
  union all
  select 12, 'الحاوية عامة (يجب 0)',
         (select count(*) from storage.buckets
           where id = 'provider-docs' and public), 0

  union all
  select 13, 'سياسات التخزين',
         (select count(*) from pg_policies
           where schemaname = 'storage' and tablename = 'objects'
             and policyname like '%documents%'), 4
)
select البند,
       الواقع,
       المتوقع,
       case when الواقع = المتوقع then '✅ سليم' else '⚠️ راجعه' end as النتيجة
  from checks
 order by ord;
