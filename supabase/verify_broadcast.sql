-- ============================================================================
--  لماذا لم يصل إشعارُ الحملة — حلقةً حلقة
--
--  يقرأ ولا يغيّر شيئاً. و«أُرسل» في اللوحة تعني أنّ الحملةَ تفرّقت صفوفاً
--  في `notifications` — لا أنّها بلغت جوالاً. وما بعدها ثلاثُ حلقات.
-- ============================================================================
with campaign as (
  select * from public.push_notifications order by created_at desc limit 1
), rows_written as (
  select count(*)::int n from public.notifications
   where data ->> 'broadcast_id' = (select id::text from campaign)
), devices as (
  select count(*)::int n from public.user_devices
   where push_token is not null and push_enabled
), devices_of_audience as (
  select count(distinct d.user_id)::int n
    from public.notifications nt
    join public.user_devices d on d.user_id = nt.user_id
   where nt.data ->> 'broadcast_id' = (select id::text from campaign)
     and d.push_token is not null and d.push_enabled
)
select 1 as ت, 'الحملة' as الحلقة,
       (select title || ' — ' || coalesce(status,'?') || ' — جمهورها: ' || audience
          from campaign) as القيمة,
       '' as "ما تفعله"
union all
select 2, '١ · تفرّقت صفوفاً في الصناديق؟',
       (select n || ' صفّاً' from rows_written),
       case when (select n from rows_written) = 0
            then '❌ لم يُكتب شيء — الجمهورُ فارغٌ أو api_admin_broadcast لم تُنادَ. شغّل broadcast.sql'
            else '✅ وصل صندوقَ التطبيق: من يفتح التطبيق يجده' end
union all
select 3, '٢ · الصندوقُ مربوطٌ بدالّة الدفع؟',
       (select case when count(*) > 0 then 'نعم' else 'لا' end from pg_trigger
         where tgname = 'push_on_notification' and not tgisinternal),
       case when (select count(*) from pg_trigger
                   where tgname = 'push_on_notification' and not tgisinternal) = 0
            then '❌ لا مُشغِّل — شغّل push_hook.sql ثم: select public.enable_push_webhook(''https://‹مشروعك›.supabase.co'');'
            else '✅ كلُّ صفٍّ جديدٍ ينادي دالّة push' end
union all
select 4, '٣ · أجهزةٌ سجّلت رمزَها أصلاً؟',
       (select n || ' جهازاً' from devices),
       case when (select n from devices) = 0
            then '❌ لا جهازَ واحدٌ سجّل رمزه — الحلقةُ مقطوعةٌ هنا. ثبّت الحزمة على جوالٍ حقيقيّ وسجّل الدخول وائذن بالإشعارات'
            else '✅' end
union all
select 5, '٤ · ومن جمهورِ هذه الحملة، كم له جهاز؟',
       (select n || ' من ' || (select n from rows_written) from devices_of_audience),
       case when (select n from devices_of_audience) = 0
            then '❌ لا أحدَ من جمهورها له جهازٌ مسجَّل — فلا شيءَ يُدفَع إليه ولو كان كلُّ ما قبله سليماً'
            else '✅ هؤلاء كان يجب أن يصلهم. فإن لم يصل: العلّةُ في دالّة push — افتح سجلّها' end;
