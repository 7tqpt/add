-- ============================================================================
--  حملات الإشعارات: من صفٍّ في اللوحة إلى جوالات الناس
--
--  شغّله بعد `notifications.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان يقع قبل هذا الملف:** صفحةُ «الإشعارات» في اللوحة تكتب صفّاً في
--  `push_notifications` وتعرضه «مُرسل ✅» — ولا أحد يقرأ ذلك الجدول. لا
--  التطبيق، ولا دالّةُ الدفع، ولا مُشغِّلٌ واحد. فالمسؤول يكتب «عرضٌ خاصّ لكل
--  العملاء» ويضغط «إرسال»، فيُقال له إنه أُرسل ولا يصل أحداً شيء. وشاشةٌ
--  تكذب أسوأ من شاشةٍ ناقصة: الناقصة تُعرف فتُكمَل، والكاذبة يُبنى عليها.
--
--  **والحلّ ليس دفعاً ثانياً:** الطريق إلى الجوال مبنيٌّ كلُّه — صفٌّ في
--  `notifications` يوقظ `push_on_notification` فدالّةَ الحافة فـFCM. فما نقص
--  هو الجسر: حملةٌ واحدة تتفرّق صفوفاً، صفّاً لكل من تعنيه. وبذلك تصل الحملة
--  إلى الجوال المغلق، وتبقى في صندوق التطبيق لمن فتحه بعد أيام.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- من تعنيه الحملة
--
--  دالّةٌ مستقلّة ليُقاس الجمهور قبل الإرسال لا بعده: «كم سيصل هذا؟» سؤالٌ
--  يُسأل قبل الضغط لا بعده.
--
--  والموقوفون خارجَ كل جمهور: من أوقفنا حسابه لا يُرسَل إليه عرضٌ ترويجي.
-- ----------------------------------------------------------------------------
create or replace function public.broadcast_audience(p_audience text)
returns setof public.app_users
language sql stable security definer set search_path = public as $$
  select u.* from public.app_users u
   where u.status <> 'suspended'
     and case p_audience
       when 'all'       then true
       when 'ios'       then u.platform = 'ios'
       when 'android'   then u.platform = 'android'
       -- «نشِط» = ظهر في الشهر الأخير. ومن لا تاريخ ظهورٍ له غيرُ نشِط: هو لم
       -- يُفتح له التطبيق منذ سُجّل.
       when 'active'    then u.last_seen_at >= now() - interval '30 days'
       when 'inactive'  then u.last_seen_at is null
                             or u.last_seen_at < now() - interval '30 days'
       when 'providers' then exists (
         select 1 from public.service_providers p where p.user_id = u.id)
       when 'customers' then not exists (
         select 1 from public.service_providers p where p.user_id = u.id)
       else false
     end
$$;

comment on function public.broadcast_audience(text) is
  'صفوف app_users التي يعنيها جمهورُ حملةٍ ما — تُستعمل للإرسال ولتقدير العدد.';

-- ----------------------------------------------------------------------------
-- الإرسال
--
--  `security definer` لأنها تكتب في صندوق كل مستخدم، وسياسةُ الصندوق تحصر
--  الكتابة في `can_write()`. والفحص هنا صريحٌ لا متروكٌ للسياسة: الدالّة
--  تتخطّاها بحكم تعريفها.
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_broadcast(p_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  campaign public.push_notifications;
  sent integer;
begin
  if not public.can_write_area('ops') then
    raise exception 'لا صلاحية لإرسال الحملات';
  end if;

  select * into campaign from public.push_notifications where id = p_id;
  if not found then
    raise exception 'لا حملة بهذا المعرّف';
  end if;

  -- **حارسُ التكرار.** ضغطتان على «إرسال» — أو تشغيلان للمجدولة — يعنيان
  -- إشعارين على جوال كل مستخدم بالنصّ نفسه. و`sent_at` هو الأثر الذي يفصل.
  if campaign.sent_at is not null then
    raise exception 'أُرسلت هذه الحملة من قبل في %', campaign.sent_at;
  end if;

  insert into public.notifications (user_id, kind, title, body, data)
  select u.id, 'general', campaign.title, campaign.body,
         jsonb_build_object('broadcast_id', campaign.id)
    from public.broadcast_audience(campaign.audience) u;
  get diagnostics sent = row_count;

  update public.push_notifications
     set status = 'sent', sent_at = now(), recipients = sent
   where id = p_id;

  return sent;
end $$;

comment on function public.api_admin_broadcast(uuid) is
  'يفرّق حملةً على صناديق جمهورها فتصل جوالاتهم. لا تُرسَل الحملة مرّتين.';

-- ----------------------------------------------------------------------------
-- المجدولة التي حان وقتها
--
--  تُنادى من جدولٍ دوريّ. وهي آمنةٌ عند التكرار بحكم حارس `sent_at`، فتشغيلان
--  متزامنان لا يُنتجان إشعارين.
-- ----------------------------------------------------------------------------
create or replace function public.send_due_broadcasts()
returns integer
language plpgsql security definer set search_path = public as $$
declare
  due public.push_notifications;
  count_sent integer := 0;
  campaign_rows integer;
begin
  for due in
    select * from public.push_notifications
     where status = 'scheduled' and sent_at is null
       and scheduled_at is not null and scheduled_at <= now()
     order by scheduled_at
     -- من فاتته دورةٌ لا يُرسَل إليه مرّتين، ومن يقرأ الصفَّ الآن يقفله عن
     -- غيره: جدولان يعملان معاً (أو تشغيلٌ يدويٌّ مع الجدول) يقتسمان الحملات
     -- ولا يكرّرانها.
     for update skip locked
  loop
    insert into public.notifications (user_id, kind, title, body, data)
    select u.id, 'general', due.title, due.body,
           jsonb_build_object('broadcast_id', due.id)
      from public.broadcast_audience(due.audience) u;
    get diagnostics campaign_rows = row_count;

    update public.push_notifications
       set status = 'sent', sent_at = now(), recipients = campaign_rows
     where id = due.id;

    count_sent := count_sent + 1;
  end loop;

  return count_sent;
end $$;

comment on function public.send_due_broadcasts() is
  'يُرسل الحملات المجدولة التي حان وقتها. يُنادى من جدولٍ دوريّ، وآمنٌ عند التكرار.';

revoke execute on function public.send_due_broadcasts() from public, authenticated;
grant execute on function public.api_admin_broadcast(uuid) to authenticated;
grant execute on function public.broadcast_audience(text) to authenticated;

-- ----------------------------------------------------------------------------
-- الجدول الدوريّ — إن أمكن
--
--  `pg_cron` موجودٌ في Supabase ويُفعَّل بأمر، ولا وجود له في قاعدةٍ محلّية.
--  فالمحاولة محروسةٌ كلُّها: إن لم تُتَح بقيت الحملات المجدولة تنتظر زرّ
--  «أرسل الآن» في اللوحة، ولم يسقط هذا الملف.
--
--  وكلُّ خمس دقائق لا كلَّ دقيقة: حملةٌ تتأخّر أربع دقائق لا يلحظها أحد،
--  واستيقاظٌ كلَّ دقيقة على قاعدةٍ نائمة يُحسب في الفاتورة.
-- ----------------------------------------------------------------------------
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron غير متاح (%) — الحملات المجدولة تُرسَل بزرّ «أرسل الآن».', sqlerrm;
    return;
  end;

  perform cron.unschedule('send-due-broadcasts')
    where exists (select 1 from cron.job where jobname = 'send-due-broadcasts');

  perform cron.schedule(
    'send-due-broadcasts', '*/5 * * * *',
    'select public.send_due_broadcasts()');
  raise notice 'جُدول الإرسال كلّ خمس دقائق.';
exception when others then
  raise notice 'تعذّر جدولة الإرسال (%) — استعمل زرّ «أرسل الآن».', sqlerrm;
end $$;

-- ============================================================================
--  الفحص
-- ============================================================================
select 'دالّة الإرسال' as البند,
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_admin_broadcast')
       then '✅' else '❌' end as الحال
union all
select 'دالّة المجدولة',
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'send_due_broadcasts')
       then '✅' else '❌' end
union all
select 'الجدول الدوريّ',
       case when exists (
         select 1 from pg_namespace where nspname = 'cron')
       then '✅ pg_cron مفعّل' else '⚠️ غير مفعّل — أرسل المجدولة بزرّ «أرسل الآن»' end;
