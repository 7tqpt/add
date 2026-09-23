-- ============================================================================
--  مَن يملك الدالّةَ ومَن يملك الجدول — وهل تراه الدالّةُ أصلاً
--
--  يقرأ ولا يغيّر شيئاً. وجملةٌ واحدة.
-- ============================================================================
--
--  ثبت بالقياس: نصُّ الدوالّ هو نصُّ المستودع حرفاً (والفرقُ الذي رأيته
--  أوّلاً كان نهاياتِ أسطرٍ CRLF لا منطقاً)، و`broadcast_audience('all')`
--  تُخرج ثلاثةً في المحرّر، وثلاثةُ مستخدمين بأجهزتهم كانوا موجودين وقتَ
--  كلّ حملة — والحملاتُ كلُّها سجّلت صفراً.
--
--  **فبقي فرقُ السياق.** `security definer` تعمل بصلاحية **مالكِ الدالّة**.
--  وRLS لا تُطبَّق على **مالكِ الجدول** — فإن كان مالكُ الدالّة غيرَ مالكِ
--  الجدول، ولا يحمل `bypassrls`، طُبِّقت عليه سياساتُ `app_users`.
--
--  وسياستُها `users_self_read`: كلٌّ يرى صفَّه. ومسؤولُ اللوحة قد لا يكون
--  له صفٌّ في `app_users` أصلاً — فتخرج الدالّةُ بصفرٍ **بلا عطبٍ ولا رسالة**،
--  بينما أرى أنا في المحرّر ثلاثةً لأنّي أعمل بدورٍ آخر.
--
--  وهذا يفسّر كلَّ ما رأيناه، ولا يفسّره غيرُه بعد أن أُغلق ما سواه.
-- ============================================================================

select 1 as ت, 'الدورُ الذي يعمل به هذا المحرّر' as البند,
       current_user || '  (bypassrls: '
         || (select case when rolbypassrls then 'نعم' else 'لا' end
               from pg_roles where rolname = current_user)
         || ' · superuser: '
         || (select case when rolsuper then 'نعم' else 'لا' end
               from pg_roles where rolname = current_user) || ')' as القيمة

union all
select 2, 'مالكُ جدول app_users',
       (select pg_get_userbyid(k.relowner)
          from pg_class k join pg_namespace n on n.oid = k.relnamespace
         where n.nspname = 'public' and k.relname = 'app_users')

union all
select 3, 'مالكُ ' || p.proname,
       pg_get_userbyid(p.proowner)
         || '  (bypassrls: '
         || (select case when r.rolbypassrls then 'نعم' else 'لا' end
               from pg_roles r where r.oid = p.proowner)
         || ' · superuser: '
         || (select case when r.rolsuper then 'نعم' else 'لا' end
               from pg_roles r where r.oid = p.proowner) || ')'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('api_admin_broadcast', 'broadcast_audience')

union all
select 4, 'أهي security definer فعلاً؟',
       (select string_agg(p.proname || ': '
                 || case when p.prosecdef then 'نعم' else '❌ لا — invoker!' end, ' · '
                 order by p.proname)
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public'
           and p.proname in ('api_admin_broadcast', 'broadcast_audience'))

union all
select 5, 'سياساتُ القراءة على app_users',
       coalesce((select string_agg(policyname, ' · ' order by policyname)
                   from pg_policies
                  where schemaname = 'public' and tablename = 'app_users'
                    and cmd in ('SELECT', 'ALL')), '— لا سياسةَ قراءة —')

union all
select 6, '— الحكم —',
       case
         when (select pg_get_userbyid(k.relowner) from pg_class k
                 join pg_namespace n on n.oid = k.relnamespace
                where n.nspname = 'public' and k.relname = 'app_users')
            = (select pg_get_userbyid(p.proowner) from pg_proc p
                 join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'broadcast_audience')
         then '✅ المالكُ واحدٌ — فالحرزُ لا يُعمي الدالّة، والعلّةُ في موضعٍ آخر.'
         else '❌ **مالكُ الدالّة غيرُ مالكِ الجدول** — فتُطبَّق عليها سياساتُ app_users، فترى صفَّ المنادي وحدَه أو لا ترى شيئاً. وهذه هي العلّة.'
       end
order by ت, البند;
