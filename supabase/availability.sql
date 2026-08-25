-- ============================================================================
--  تقويم مقدّم الخدمة: يوم يُغلق بحجز، ويوم يُغلق بعذر — وكلاهما يُفتح
--
--  شغّله بعد `api.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **العطب الذي يُصلحه:** `api_respond_to_booking` تُغلق يوم الحدث فور تأكيد
--  الحجز — وهذا صواب، فلا يُحجز يومان على قاعةٍ واحدة. لكن **لا سطرَ واحد في
--  المشروع كلِّه يفتح ذلك اليوم عند الإلغاء**. فحجزٌ أُلغي بعد ساعةٍ من تأكيده
--  يترك يوم صاحب القاعة مغلقاً إلى الأبد: يمرّ عليه الموسم فلا يصله طلبٌ
--  واحد، ولا شاشة تُريه تقويمه ليعرف لماذا. خسارةٌ صامتة لا يشتكي منها أحد
--  لأن أحداً لا يراها.
--
--  **ولماذا مُشغِّلٌ لا تعديلٌ في الدوال الثلاث:** الحجز يُلغى من ثلاثة أبواب —
--  العميل من التطبيق، والمزوّد باعتذاره، والإدارة من اللوحة — ويُضاف رابعٌ
--  غداً. والمُشغِّل يقع على الجدول نفسه فيلزمها كلَّها بلا استثناء، ولا يُنسى
--  حين تُكتب دالّةٌ جديدة.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ١. المُشغِّل: الحالة تقود التقويم
--
--  والحذف **مشروطٌ بالملاحظة**: اليوم قد يكون مغلقاً بعذرٍ كتبه صاحبه («سفر»)
--  أو بحجزٍ آخر في اليوم نفسه لخدمةٍ أخرى. فحذفٌ بالتاريخ وحده يفتح ما لم
--  يُغلقه هذا الحجز — ويفتح باب حجزٍ فوق حجز.
-- ----------------------------------------------------------------------------
create or replace function public.sync_booking_day()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  mark text := 'محجوز — ' || new.reference;
begin
  if new.provider_id is null or new.event_date is null then
    return new;
  end if;

  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (new.provider_id, new.event_date, true, mark)
    on conflict (provider_id, day) do nothing;

  elsif new.status in ('cancelled', 'rejected', 'expired')
        and old.status is distinct from new.status then
    delete from public.provider_availability
     where provider_id = new.provider_id
       and day = new.event_date
       and note = mark;
  end if;

  return new;
end $$;

drop trigger if exists booking_day_sync on public.bookings;
create trigger booking_day_sync
  after update of status on public.bookings
  for each row execute function public.sync_booking_day();

-- ----------------------------------------------------------------------------
-- ٢. تنظيفُ ما خلّفه العطب
--
--  أيامٌ مغلقةٌ بأسماء حجوزاتٍ لم تعد قائمة. تُحذف مرّةً واحدة، والمُشغِّل يمنع
--  تكرارها. ويُطابَق باسم الحجز لا بالتاريخ، فلا يُفتح يومٌ أغلقه صاحبه بعذر.
-- ----------------------------------------------------------------------------
delete from public.provider_availability a
 using public.bookings b
 where a.provider_id = b.provider_id
   and a.day = b.event_date
   and a.note = 'محجوز — ' || b.reference
   and b.status in ('cancelled', 'rejected', 'expired');

-- ----------------------------------------------------------------------------
-- ٣. المزوّد يغلق يومه ويفتحه
--
--  **ولا يفتح يوماً فيه حجزٌ مؤكّد:** لو فُتح لأمكن أن يُحجز فوقه حجزٌ ثانٍ،
--  فيجد صاحب القاعة نفسه أمام عرسين في ليلةٍ واحدة — وهو أسوأ ما يقع في هذا
--  العمل. والملاحظة هي التي تفرّق: ما بدأ بـ«محجوز —» من صنع القاعدة لا من
--  صنعه.
-- ----------------------------------------------------------------------------
create or replace function public.api_set_availability(
  p_day date, p_blocked boolean, p_note text default '')
returns public.provider_availability
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.current_provider();
  row public.provider_availability;
  held text;
begin
  if me is null then
    raise exception 'هذه الشاشة لمقدّمي الخدمة';
  end if;
  if p_day < current_date then
    raise exception 'لا يُعدَّل يومٌ مضى';
  end if;

  select note into held from public.provider_availability
   where provider_id = me and day = p_day;

  if held is not null and held like 'محجوز — %' then
    if p_blocked then
      -- مغلقٌ أصلاً بحجز؛ الطلب لا يغيّر شيئاً فيُعاد الصفّ كما هو.
      select * into row from public.provider_availability
       where provider_id = me and day = p_day;
      return row;
    end if;
    raise exception 'هذا اليوم محجوز (%) — ألغِ الحجز أوّلاً', held;
  end if;

  if p_blocked then
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (me, p_day, true, coalesce(nullif(trim(p_note), ''), 'غير متاح'))
    on conflict (provider_id, day) do update
      set is_blocked = true, note = excluded.note
    returning * into row;
    return row;
  end if;

  delete from public.provider_availability
   where provider_id = me and day = p_day
  returning * into row;
  return row;
end $$;

comment on function public.api_set_availability(date, boolean, text) is
  'يغلق مقدّمُ الخدمة يوماً في تقويمه أو يفتحه. لا يفتح يوماً فيه حجزٌ مؤكّد.';

-- ----------------------------------------------------------------------------
-- ٤. تقويمي — بملاحظاته
-- ----------------------------------------------------------------------------
create or replace function public.api_my_days(p_from date, p_to date)
returns setof public.provider_availability
language sql stable security definer set search_path = public as $$
  select * from public.provider_availability
   where provider_id = public.current_provider()
     and day between p_from and p_to
   order by day
$$;

-- ----------------------------------------------------------------------------
-- ٥. أيام مزوّدٍ المغلقة — لمن يريد أن يحجز
--
--  تُعيد التواريخ وحدها بلا ملاحظات: أن يعرف العميل أن اليوم مشغول حقُّه،
--  وأن يقرأ رقم حجز غيره ليس منه في شيء.
-- ----------------------------------------------------------------------------
create or replace function public.api_blocked_days(
  p_provider_id uuid, p_from date, p_to date)
returns setof date
language sql stable security definer set search_path = public as $$
  select day from public.provider_availability
   where provider_id = p_provider_id
     and is_blocked
     and day between p_from and p_to
   order by day
$$;

-- ----------------------------------------------------------------------------
-- ٦. والملاحظة تُحجب عن غير صاحبها
--
--  سياسة القراءة العامّة تكشف الصفّ كلَّه، وفيه «محجوز — BK-2026-0007». فيُنزع
--  عمود الملاحظة من صلاحية القراءة العامّة ويبقى بابُه `api_my_days` لصاحبه.
--  وهذا منحُ أعمدةٍ لا سياسةُ صفوف: RLS لا تحجب عموداً.
-- ----------------------------------------------------------------------------
revoke select on public.provider_availability from anon, authenticated;
grant select (id, provider_id, day, is_blocked)
  on public.provider_availability to anon, authenticated;
grant insert, update, delete on public.provider_availability to authenticated;

grant execute on function public.api_set_availability(date, boolean, text) to authenticated;
grant execute on function public.api_my_days(date, date) to authenticated;
grant execute on function public.api_blocked_days(uuid, date, date) to anon, authenticated;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'مُشغِّل التقويم' as البند,
       case when exists (select 1 from pg_trigger where tgname = 'booking_day_sync')
       then '✅' else '❌' end as الحال
union all
select 'دالّة الإغلاق والفتح',
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_set_availability')
       then '✅' else '❌' end
union all
select 'أيامٌ مغلقةٌ بحجوزاتٍ ملغاة',
       case when exists (
         select 1 from public.provider_availability a
          join public.bookings b on b.provider_id = a.provider_id and b.event_date = a.day
          where a.note = 'محجوز — ' || b.reference
            and b.status in ('cancelled', 'rejected', 'expired'))
       then '❌ ما زالت' else '✅ لا شيء' end;
