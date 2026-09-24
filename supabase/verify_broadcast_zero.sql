-- ============================================================================
--  لماذا تكتب كلُّ حملةٍ صفراً — والجمهورُ ثلاثةٌ حين يُسأل مباشرةً
--
--  يقرأ ولا يغيّر شيئاً. **وجملةٌ واحدةٌ عمداً** — المحرّرُ يعرض آخرَ جملة.
-- ============================================================================
--
--  `api_admin_broadcast` تفعل هذا:
--
--    insert into notifications (…) select … from broadcast_audience(campaign.audience);
--    get diagnostics sent = row_count;              ← صفر
--    update push_notifications set status = 'sent', recipients = sent;
--
--  فالوسمُ «sent» يقع **مهما كان العدد**. وصفرٌ يعني أنّ
--  `broadcast_audience(campaign.audience)` أخرجت صفراً — **بقيمة الجمهور
--  المخزَّنة**، لا بـ`'all'` التي أكتبها أنا في المحرّر.
--
--  وهذا هو الفرق الذي يُخفيه فحصٌ يسأل بـ`'all'` حرفيّاً: عمودُ `audience`
--  قد يحمل فراغاً لاحقاً أو حرفاً كبيراً أو قيمةً أخرى — فيقع في `else false`
--  في `case`، فيخرج صفراً، ولا يُرى في عرضٍ عاديٍّ للعمود.
-- ============================================================================

with c as (
  select * from public.push_notifications order by created_at desc limit 1
)
select 1 as ت,
       'الجمهورُ كما هو مخزَّنٌ — بين قوسين ليُرى الفراغ' as البند,
       '[' || coalesce((select audience from c), '‹NULL›') || ']'
         || '  · طولُه: ' || coalesce(length((select audience from c))::text, '—') as القيمة
union all
select 2, '**ما تُخرجه بالقيمة المخزَّنة**',
       (select count(*)::text from public.broadcast_audience((select audience from c)))
union all
select 3, 'وما تُخرجه بـ all حرفيّاً',
       (select count(*)::text from public.broadcast_audience('all'))
union all
select 4, 'مستخدمون في app_users · وحالاتُهم',
       (select count(*)::text from public.app_users) || ' — '
       || coalesce((select string_agg(x.s || ':' || x.n, ' · ' order by x.s)
                      from (select coalesce(status,'‹NULL›') s, count(*)::text n
                              from public.app_users group by 1) x), '—')
union all
select 5, 'نسخُ الدالّتين — وأكثرُ من واحدةٍ تعني نداءَ غيرِ ما تظنّ',
       (select count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'api_admin_broadcast')
       || ' × api_admin_broadcast · '
       || (select count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'broadcast_audience')
       || ' × broadcast_audience'
union all
select 6, 'أفي broadcast_audience فرعُ all أصلاً؟',
       (select case when bool_or(prosrc like '%when ''all''%')
                    then 'نعم' else '❌ لا — نسخةٌ أخرى' end
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'broadcast_audience')
union all
select 7, '**الشرطُ الخامُّ بلا دالّة**: status <> suspended',
       (select count(*)::text from public.app_users where status <> 'suspended')
union all
select 8, 'أيُجبَر الحرزُ على مالك الجدول؟ (force RLS يُعمي الدوالَّ)',
       (select case when bool_or(relforcerowsecurity)
                    then '❌ نعم — وهذا يُفرغ security definer من معناه'
                    else 'لا — والدوالُّ ترى الصفوف' end
          from pg_class k join pg_namespace n on n.oid = k.relnamespace
         where n.nspname = 'public' and k.relname = 'app_users')
union all
select 9, 'وكلُّ حملةٍ: جمهورُها · ما سجّلته · حالُها',
       coalesce((select string_agg('[' || audience || '] ' || coalesce(recipients::text,'NULL')
                                   || ' ' || status, '  |  ' order by created_at desc)
                   from public.push_notifications), '—')
order by ت;
