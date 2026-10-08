-- ============================================================================
--  مقدّمُ الخدمة مقيَّدٌ بأقسامه
-- ============================================================================
--
--  سأل صاحبُ المنصّة: «كيف اقيد المقدم الخدمة ب القسام الذي اختارة». وكان
--  المزوّدُ يختار قسماً حين يسجّل، ثمّ تعرض له ورقةُ «خدمة جديدة» الأقسامَ
--  كلَّها والقاعدةُ تقبل — صاحبُ قاعةٍ يضيف «تصوير». **بل كان يستطيع أن يضيف
--  لنفسه قسماً** بكتابةٍ مباشرةٍ في `provider_categories`: سياستُها `for all`
--  لصاحبها.
--
--  واختار (أ ب):
--    (أ) **الإدارةُ تغيّر قسمَه** من صفحته في اللوحة، وتضيف له ثانياً.
--    (ب) **وخدماتُه في قسمٍ غير أقسامه تُخفى عن العملاء** حتى تُراجَع: تضيف
--        الإدارةُ قسمَها له، أو يعدّلها هو إلى قسمه.
--
--  ── والإخفاءُ حسابٌ لا علَم ────────────────────────────────────────────────
--
--  لا عمودَ «مخفيّة» يُكتب ويُنسى: الخدمةُ تُرى إن كان قسمُها من أقسام صاحبها
--  الآن. فإضافةُ القسم تُعيدها، وحذفُه يُخفيها، بلا خطوةٍ ثانية.
--
--  وكلُّ ما يقرؤه العميلُ يمرّ بسياسة `services_public_read`: `v_services`
--  بـ`security_invoker`، و`api_services_nearby` تقرأ منها، والمفضّلةُ وصفحةُ
--  المزوّد كذلك. فتكفي السياسةُ — ويُحرس الحجزُ بمُطلِقٍ وحده، لأنّ دالّته
--  `security definer` لا تمرّ بها.
--
--  ⚠️ و`security_hardening.sql` يعيد سياسةَ `provider_categories_owner` القديمة:
--  **إن أُعيد لصقُه فليُعَد لصقُ هذا بعده.**
--
--  التشغيل: بعد `promotions_clear.sql` — وإعادةُ اللصق آمنة.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
--  ١. أهذا القسمُ من أقسامه؟
-- ----------------------------------------------------------------------------
--  `security definer`: تُسأل من سياسةٍ يقيّمها الزائرُ أيضاً، فلا تتعلّق بما
--  يراه هو من `provider_categories`.
create or replace function public.service_in_provider_categories(p_provider uuid, p_category uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.provider_categories pc
     where pc.provider_id = p_provider and pc.category_id = p_category)
$$;

-- ----------------------------------------------------------------------------
--  ٢. العميلُ لا يرى خدمةً خارج أقسام صاحبها — وصاحبُها والإدارةُ يرونها
-- ----------------------------------------------------------------------------
drop policy if exists services_public_read on public.provider_services;
create policy services_public_read on public.provider_services
  for select to anon, authenticated
  using (
    (is_active
     and exists (select 1 from public.service_providers p
                  where p.id = provider_id and p.status = 'verified')
     and public.service_in_provider_categories(provider_id, category_id))
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- ----------------------------------------------------------------------------
--  ٣. والمزوّدُ لا يكتب أقسامَه — الإدارةُ وحدها
-- ----------------------------------------------------------------------------
--  والتسجيلُ (`api_register_provider`) دالّةٌ `security definer` فلا يمسّه هذا.
drop policy if exists provider_categories_owner on public.provider_categories;
drop policy if exists provider_categories_admin_write on public.provider_categories;
create policy provider_categories_admin_write on public.provider_categories
  for all to authenticated
  using (public.can_write_area('directory') or public.can_write_area('catalog'))
  with check (public.can_write_area('directory') or public.can_write_area('catalog'));

-- ----------------------------------------------------------------------------
--  ٤. ولا تُضاف خدمةٌ — ولا يُنقل قسمُها — إلّا إلى أقسامه
-- ----------------------------------------------------------------------------
--  **وتعديلُ غير القسم مسموحٌ لخدمةٍ مخفيّة:** يغيّر سعرَها ولا تظهر، فإن
--  نقلها إلى قسمه ظهرت. ولو رُدّ كلُّ تعديلٍ لها لَما استطاع إصلاحها.
--  ومن لا هويّةَ له (محرّرُ SQL، والبذور) والإدارةُ يمرّان.
create or replace function public.guard_service_category()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null
     or public.can_write_area('catalog') or public.can_write_area('directory') then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and new.category_id is not distinct from old.category_id
     and new.provider_id is not distinct from old.provider_id then
    return new;
  end if;
  if not public.service_in_provider_categories(new.provider_id, new.category_id) then
    raise exception 'لا تُضاف خدمةٌ إلّا في قسمك المسجَّل.';
  end if;
  return new;
end $$;

drop trigger if exists guard_service_category on public.provider_services;
create trigger guard_service_category
  before insert or update on public.provider_services
  for each row execute function public.guard_service_category();

-- ----------------------------------------------------------------------------
--  ٥. ولا تُحجز خدمةٌ مخفيّة — برابطٍ قديمٍ أو مفضّلةٍ محفوظة
-- ----------------------------------------------------------------------------
create or replace function public.guard_booking_service_category()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  svc public.provider_services;
begin
  if new.service_id is null or auth.uid() is null or public.can_write_area('bookings') then
    return new;
  end if;
  select * into svc from public.provider_services where id = new.service_id;
  if found and not public.service_in_provider_categories(svc.provider_id, svc.category_id) then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';
  end if;
  return new;
end $$;

drop trigger if exists guard_booking_service_category on public.bookings;
create trigger guard_booking_service_category
  before insert on public.bookings
  for each row execute function public.guard_booking_service_category();

-- ----------------------------------------------------------------------------
--  ٦. الإدارةُ تضبط أقسامَه — قسماً واحداً على الأقلّ
-- ----------------------------------------------------------------------------
--  تُرجع عددَ خدماته المخفيّة بعد الحفظ، ليقوله التأكيد.
create or replace function public.api_admin_set_provider_categories(
  p_provider_id  uuid,
  p_category_ids uuid[]
)
returns table (hidden integer)
language plpgsql security definer set search_path = public as $$
declare
  wanted uuid[] := array(select distinct unnest(coalesce(p_category_ids, '{}')));
  before_names text;
  after_names  text;
begin
  if not public.can_write_area('directory') then
    raise exception 'تغييرُ أقسام مقدّم الخدمة لمن يدير مقدّمي الخدمة';
  end if;
  if not exists (select 1 from public.service_providers where id = p_provider_id) then
    raise exception 'مقدّمُ الخدمة غير موجود';
  end if;
  if coalesce(array_length(wanted, 1), 0) = 0 then
    raise exception 'اختر قسماً واحداً على الأقلّ';
  end if;
  if exists (select 1 from unnest(wanted) w
              where not exists (select 1 from public.service_categories c where c.id = w)) then
    raise exception 'قسمٌ غير موجود';
  end if;

  select string_agg(c.name, '، ' order by c.sort_order) into before_names
    from public.provider_categories pc join public.service_categories c on c.id = pc.category_id
   where pc.provider_id = p_provider_id;

  delete from public.provider_categories
   where provider_id = p_provider_id and category_id <> all (wanted);
  insert into public.provider_categories (provider_id, category_id)
  select p_provider_id, w from unnest(wanted) w
  on conflict do nothing;

  select string_agg(c.name, '، ' order by c.sort_order) into after_names
    from public.provider_categories pc join public.service_categories c on c.id = pc.category_id
   where pc.provider_id = p_provider_id;

  if after_names is distinct from before_names then
    perform public.notify_provider(
      p_provider_id, 'account', 'تغيّرت أقسامُك',
      'أقسامُك الآن: ' || after_names || '. وتُضاف خدماتُك فيها وحدها.',
      jsonb_build_object('categories', wanted));
  end if;

  return query
    select count(*)::integer from public.provider_services s
     where s.provider_id = p_provider_id
       and not public.service_in_provider_categories(s.provider_id, s.category_id);
end $$;

revoke execute on function public.api_admin_set_provider_categories(uuid, uuid[]) from public, anon;
grant execute on function public.api_admin_set_provider_categories(uuid, uuid[]) to authenticated;

commit;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
--  تحقّق: الخدماتُ المخفيّةُ الآن — خارج أقسام أصحابها
-- ----------------------------------------------------------------------------
select coalesce(nullif(p.business_name, ''), p.full_name) as "مقدّم الخدمة",
       s.title as "الخدمة",
       c.name  as "قسمُها"
  from public.provider_services s
  join public.service_providers p on p.id = s.provider_id
  join public.service_categories c on c.id = s.category_id
 where not public.service_in_provider_categories(s.provider_id, s.category_id)
 order by 1, 2;
