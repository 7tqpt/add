-- ============================================================================
--  لماذا خرج جمهورُ الحملة صفراً — والدالّةُ نجحت ووسمت «sent»
--
--  يقرأ ولا يغيّر شيئاً.
-- ============================================================================
select 1 as ت, 'الحملة: كم صندوقاً قالت إنّها بلغت؟' as البند,
       (select coalesce(recipients::text, 'NULL') || '  (الحال: ' || status || ')'
          from public.push_notifications order by created_at desc limit 1) as القيمة

union all
select 2, 'كم مستخدماً في app_users أصلاً؟',
       (select count(*)::text from public.app_users)

union all
select 3, 'وحالاتُهم — والفراغُ يُقصي صاحبَه',
       (select coalesce(string_agg(x.s || ': ' || x.n, ' · ' order by x.s), '—')
          from (select coalesce(status, '‹فارغ NULL›') as s, count(*)::text as n
                  from public.app_users group by 1) x)

union all
select 4, 'كم يُخرج broadcast_audience(''all'')؟',
       (select count(*)::text from public.broadcast_audience('all'))

union all
select 5, '**ومن يُقصيه شرطُ status وحدَه**',
       (select count(*)::text from public.app_users where status is null)

union all
select 6, 'كم صفّاً في notifications كلِّه؟',
       (select count(*)::text from public.notifications)

union all
select 7, 'وكم منها لهذه الحملة؟',
       (select count(*)::text from public.notifications
         where data ->> 'broadcast_id'
             = (select id::text from public.push_notifications
                 order by created_at desc limit 1))

union all
select 8, 'ونسخةُ الدالّة: أتكتب في notifications؟',
       (select case when prosrc like '%insert into public.notifications%'
                    then 'نعم — النسخةُ الصحيحة' else '❌ نسخةٌ قديمةٌ لا تكتب شيئاً' end
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'api_admin_broadcast')

union all
select 9, 'والأجهزةُ الخمسة: لأيّ مستخدمين؟',
       (select count(distinct user_id)::text || ' مستخدماً منهم '
            || (select count(*)::text from public.app_users u
                 where exists (select 1 from public.user_devices d
                                where d.user_id = u.id and d.push_token is not null))
            || ' موجودون في app_users'
          from public.user_devices where push_token is not null)
order by ت;
