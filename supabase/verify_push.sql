-- ============================================================================
--  فحص الإشعارات: ما الذي يعمل وما الذي ينقص
--
--  شغّله كاملاً في محرّر SQL. لا يغيّر شيئاً — يقرأ ويحكم.
-- ============================================================================
--
--  وكلُّ سطرٍ يقول **ما الذي تفعله** لا «صواب/خطأ» فقط: من قرأ «❌» ولم يعرف
--  الخطوة التالية لم ينتفع بالفحص.
-- ============================================================================

with checks as (

  select 1 as ترتيب, 'جدول الإشعارات' as البند,
         (select count(*) > 0 from information_schema.tables
           where table_schema = 'public' and table_name = 'notifications') as حسن,
         'شغّل install.sql' as الخطوة

  union all
  select 2, 'مُشغِّل إشعار الرسالة',
         (select count(*) > 0 from pg_trigger
           where tgname = 'notify_conversation_message' and not tgisinternal),
         'شغّل chat.sql ثم notifications.sql'

  union all
  select 3, 'عمود رمز الجهاز',
         (select count(*) > 0 from information_schema.columns
           where table_schema = 'public' and table_name = 'user_devices'
             and column_name = 'push_token'),
         'شغّل notifications.sql'

  union all
  select 4, 'البثّ الحيّ للإشعارات',
         (select count(*) > 0 from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'
             and tablename = 'notifications'),
         'شغّل notifications.sql على مشروع Supabase (لا على قاعدةٍ محلّية)'

  union all
  select 5, 'البثّ الحيّ للرسائل',
         (select count(*) > 0 from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'
             and tablename = 'conversation_messages'),
         'شغّل chat.sql'

  union all
  select 6, 'ربط الدفع بالدالّة',
         (select count(*) > 0 from pg_trigger
           where tgname = 'push_on_notification' and not tgisinternal),
         'شغّل push_hook.sql ثم enable_push_webhook(''https://…supabase.co'')'

  union all
  select 7, 'أجهزةٌ سجّلت رمزها',
         (select count(*) > 0 from public.user_devices where push_token is not null),
         'ثبّت الحزمة الجديدة على جوالٍ حقيقي وسجّل الدخول — ولا يقع هذا على محاكٍ بلا Google Play'

  union all
  select 8, 'إشعاراتٌ كُتبت فعلاً',
         (select count(*) > 0 from public.notifications),
         'احجز خدمةً أو أرسل رسالة — الصندوق يمتلئ من سبعة أحداث'
)

-- ولا اسمَ فارغاً لعمود: Postgres يرفض `as ""` — «zero-length delimited
-- identifier» — فيسقط الملف كلُّه عند أول تشغيل.
select
  case when حسن then '✅' else '❌' end as الحكم,
  البند,
  case when حسن then '—' else الخطوة end as "ما تفعله"
from checks
order by ترتيب;

-- ----------------------------------------------------------------------------
-- ملحق: آخر ما وصل، ولمن
-- ----------------------------------------------------------------------------
select
  n.kind as النوع,
  n.title as العنوان,
  case when n.read_at is null then 'جديد' else 'مقروء' end as الحال,
  coalesce(u.full_name, p.business_name, '—') as "صاحبه",
  (select count(*) from public.user_devices d
    where d.user_id = coalesce(n.user_id, p.user_id) and d.push_token is not null)
    as "أجهزته",
  n.created_at as الوقت
from public.notifications n
left join public.app_users u on u.id = n.user_id
left join public.service_providers p on p.id = n.provider_id
order by n.created_at desc
limit 10;
