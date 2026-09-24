-- ============================================================================
--  الجمهورُ ٣ اليومَ والحملةُ سجّلت صفراً — فمتى وُجد هؤلاء؟
--
--  يقرأ ولا يغيّر شيئاً.
-- ============================================================================
with c as (select * from public.push_notifications order by created_at desc limit 1)
select 'الحملةُ أُرسلت' as البند,
       to_char((select sent_at from c), 'YYYY-MM-DD HH24:MI') as الوقت,
       (select recipients::text || ' متلقّياً' from c) as التفصيل
union all
select 'مستخدمٌ: ' || u.full_name || ' (' || u.status || ')',
       to_char(u.created_at, 'YYYY-MM-DD HH24:MI'),
       case when u.created_at > (select sent_at from c)
            then '⬅ **وُجد بعد الإرسال** — فلم يكن في الجمهور'
            else 'كان موجوداً وقتَها'
       end || ' · أجهزته: '
       || (select count(*) from public.user_devices d
            where d.user_id = u.id and d.push_token is not null and d.push_enabled)
  from public.app_users u
union all
select '— آخرُ إشعارٍ وصل صندوقاً (من ' || (select count(*)::text from public.notifications) || ')',
       to_char((select max(created_at) from public.notifications), 'YYYY-MM-DD HH24:MI'),
       coalesce((select kind || ' · ' || title from public.notifications
                  order by created_at desc limit 1), '—')
order by 2;
