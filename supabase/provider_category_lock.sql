-- ============================================================================
--  أقسامُ مقدّم الخدمة — وخدمةٌ في غيرها تنتظر موافقةَ الإدارة
-- ============================================================================
--
--  سأل صاحبُ المنصّة: «كيف اقيد المقدم الخدمة ب القسام الذي اختارة». وكان
--  المزوّدُ يختار قسماً حين يسجّل، ثمّ يضيف خدماتٍ في أيّ قسمٍ فتظهر — صاحبُ
--  قاعةٍ يضيف «تصوير». **بل كان يستطيع أن يضيف لنفسه قسماً** بكتابةٍ مباشرةٍ في
--  `provider_categories`: سياستُها `for all` لصاحبها.
--
--  ثمّ ردّ الحقلَ المقفل: «مقدم الخدمة يختار القسم الذي يبغى بس لايمكنه تغيير
--  الي بعلم الادارة». واختار (ج):
--    • يختار المزوّدُ أيَّ قسم. **وما ليس من أقسامه يُحفظ «بانتظار الموافقة»**
--      ولا يراه العملاء.
--    • والإدارةُ توافق **بإضافة القسم له** («تغيير القسم» في صفحته) فتُقبل
--      خدماتُه فيه كلُّها، **أو على كلّ خدمةٍ وحدَها** («موافقة» و«رفض» بسبب).
--    • والمرفوضةُ يعدّلها صاحبُها فتعود للمراجعة.
--    • وخدماتُه القائمةُ خارج أقسامه تصير «بانتظار الموافقة» لتُراجَع.
--
--  ── `approval` هو الحَكَم ───────────────────────────────────────────────────
--
--  العميلُ يرى `approved` وحدَها: كلُّ ما يقرؤه يمرّ بسياسة `services_public_read`
--  (`v_services` بـ`security_invoker`، و`api_services_nearby` منها، والمفضّلةُ
--  وصفحةُ المزوّد). والحجزُ دالّته `security definer` فيُحرس بمُطلِق.
--  **والمزوّدُ لا يكتب `approval`:** المُطلِقُ يحسبه من القسم، ويردّ ما كتبه.
--
--  ⚠️ و`security_hardening.sql` يعيد سياسةَ `provider_categories_owner` القديمة:
--  **إن أُعيد لصقُه فليُعَد لصقُ هذا بعده.**
--
--  التشغيل: بعد `promotions_clear.sql` — وإعادةُ اللصق آمنة.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
--  ١. حالُ الموافقة على الخدمة
-- ----------------------------------------------------------------------------
alter table public.provider_services
  add column if not exists approval      text not null default 'approved',
  add column if not exists approval_note text not null default '',
  -- متى قرّرت الإدارة — وبه تُعرف الموافقةُ على خدمةٍ بعينها فلا تُنقض بإعادة اللصق.
  add column if not exists approval_at   timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'provider_services_approval_check') then
    alter table public.provider_services
      add constraint provider_services_approval_check
      check (approval in ('approved', 'pending', 'rejected'));
  end if;
end $$;

create index if not exists provider_services_pending_idx
  on public.provider_services (created_at desc) where approval <> 'approved';

-- ----------------------------------------------------------------------------
--  ٢. أهذا القسمُ من أقسامه؟
-- ----------------------------------------------------------------------------
create or replace function public.service_in_provider_categories(p_provider uuid, p_category uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.provider_categories pc
     where pc.provider_id = p_provider and pc.category_id = p_category)
$$;

-- وما كان قائماً خارج أقسام صاحبه يُراجَع — إلّا ما وافقت عليه الإدارةُ بعينه.
update public.provider_services s
   set approval = 'pending'
 where s.approval = 'approved'
   and s.approval_at is null
   and not public.service_in_provider_categories(s.provider_id, s.category_id);

-- ----------------------------------------------------------------------------
--  ٣. العميلُ يرى الموافَقَ عليه وحدَه — وصاحبُها والإدارةُ يرون كلَّ شيء
-- ----------------------------------------------------------------------------
drop policy if exists services_public_read on public.provider_services;
create policy services_public_read on public.provider_services
  for select to anon, authenticated
  using (
    (is_active
     and approval = 'approved'
     and exists (select 1 from public.service_providers p
                  where p.id = provider_id and p.status = 'verified'))
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- ----------------------------------------------------------------------------
--  ٤. والمزوّدُ لا يكتب أقسامَه — الإدارةُ وحدها
-- ----------------------------------------------------------------------------
--  والتسجيلُ (`api_register_provider`) دالّةٌ `security definer` فلا يمسّه هذا.
drop policy if exists provider_categories_owner on public.provider_categories;
drop policy if exists provider_categories_admin_write on public.provider_categories;
create policy provider_categories_admin_write on public.provider_categories
  for all to authenticated
  using (public.can_write_area('directory') or public.can_write_area('catalog'))
  with check (public.can_write_area('directory') or public.can_write_area('catalog'));

-- ----------------------------------------------------------------------------
--  ٥. الموافقةُ تُحسب من القسم حين يكتب المزوّد
-- ----------------------------------------------------------------------------
--  • خدمةٌ جديدة: في أقسامه ← `approved`، وفي غيرها ← `pending`.
--  • ونقلُها إلى قسمٍ آخر يُعيد الحساب.
--  • والمرفوضةُ إن عدّلها صاحبُها عادت للمراجعة (أو قُبلت إن نقلها إلى قسمه).
--  • وما سوى ذلك يُبقي حالَها — **وما كتبه المزوّدُ فيها يُردّ.**
--  ومن لا هويّةَ له (محرّرُ SQL، والبذور) والإدارةُ يمرّان كما كتبوا.
create or replace function public.guard_service_category()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  recompute boolean;
begin
  if auth.uid() is null
     or public.can_write_area('catalog') or public.can_write_area('directory') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    recompute := true;
  else
    new.approval      := old.approval;
    new.approval_note := old.approval_note;
    new.approval_at   := old.approval_at;
    recompute := new.category_id is distinct from old.category_id
              or new.provider_id is distinct from old.provider_id
              or old.approval = 'rejected';
  end if;

  if recompute then
    new.approval_at   := null;
    new.approval_note := '';
    new.approval := case
      when public.service_in_provider_categories(new.provider_id, new.category_id) then 'approved'
      else 'pending' end;
  end if;
  return new;
end $$;

drop trigger if exists guard_service_category on public.provider_services;
create trigger guard_service_category
  before insert or update on public.provider_services
  for each row execute function public.guard_service_category();

-- ----------------------------------------------------------------------------
--  ٦. ولا تُحجز خدمةٌ لم يُوافَق عليها — برابطٍ قديمٍ أو مفضّلةٍ محفوظة
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
  if found and svc.approval <> 'approved' then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';
  end if;
  return new;
end $$;

drop trigger if exists guard_booking_service_category on public.bookings;
create trigger guard_booking_service_category
  before insert on public.bookings
  for each row execute function public.guard_booking_service_category();

-- ----------------------------------------------------------------------------
--  ٧. الإدارةُ تضبط أقسامَه — فتُقبل خدماتُه في المضاف، وتُراجَع في المحذوف
-- ----------------------------------------------------------------------------
--  تُرجع عددَ خدماته التي لم يُوافَق عليها بعد الحفظ، ليقوله التأكيد.
create or replace function public.api_admin_set_provider_categories(
  p_provider_id  uuid,
  p_category_ids uuid[]
)
returns table (hidden integer)
language plpgsql security definer set search_path = public as $$
declare
  wanted  uuid[] := array(select distinct unnest(coalesce(p_category_ids, '{}')));
  removed uuid[];
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

  select string_agg(c.name, '، ' order by c.sort_order),
         array_agg(pc.category_id) filter (where pc.category_id <> all (wanted))
    into before_names, removed
    from public.provider_categories pc join public.service_categories c on c.id = pc.category_id
   where pc.provider_id = p_provider_id;

  delete from public.provider_categories
   where provider_id = p_provider_id and category_id <> all (wanted);
  insert into public.provider_categories (provider_id, category_id)
  select p_provider_id, w from unnest(wanted) w
  on conflict do nothing;

  -- **إضافةُ القسم موافقةٌ على خدماته فيه** — المنتظرةُ والمرفوضةُ معاً. و`approval_at`
  -- يبقى فارغاً: الموافقةُ هنا للقسم لا للخدمة، فإن حُذف القسمُ عادت للمراجعة.
  update public.provider_services
     set approval = 'approved', approval_note = '', approval_at = null
   where provider_id = p_provider_id
     and approval <> 'approved'
     and category_id = any (wanted);
  -- **وحذفُه يُعيد خدماته فيه للمراجعة** — إلّا ما وُوفق عليه بعينه.
  update public.provider_services
     set approval = 'pending', approval_at = null
   where provider_id = p_provider_id
     and approval = 'approved'
     and approval_at is null
     and category_id = any (coalesce(removed, '{}'));

  select string_agg(c.name, '، ' order by c.sort_order) into after_names
    from public.provider_categories pc join public.service_categories c on c.id = pc.category_id
   where pc.provider_id = p_provider_id;

  if after_names is distinct from before_names then
    perform public.notify_provider(
      p_provider_id, 'account', 'تغيّرت أقسامُك',
      'أقسامُك الآن: ' || after_names || '. وخدماتُك فيها تظهر للعملاء بلا انتظار.',
      jsonb_build_object('categories', wanted));
  end if;

  return query
    select count(*)::integer from public.provider_services s
     where s.provider_id = p_provider_id and s.approval <> 'approved';
end $$;

revoke execute on function public.api_admin_set_provider_categories(uuid, uuid[]) from public, anon;
grant execute on function public.api_admin_set_provider_categories(uuid, uuid[]) to authenticated;

-- ----------------------------------------------------------------------------
--  ٨. وموافقةٌ على خدمةٍ بعينها، أو رفضُها بسببٍ يصل صاحبَها
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_review_service(
  p_service_id uuid,
  p_approve    boolean,
  p_note       text default ''
)
returns public.provider_services
language plpgsql security definer set search_path = public as $$
declare
  svc public.provider_services;
begin
  if not (public.can_write_area('directory') or public.can_write_area('catalog')) then
    raise exception 'مراجعةُ الخدمات لمن يدير مقدّمي الخدمة';
  end if;
  if not p_approve and btrim(coalesce(p_note, '')) = '' then
    raise exception 'اكتب سبب الرفض — يصل مقدّمَ الخدمة';
  end if;

  update public.provider_services
     set approval      = case when p_approve then 'approved' else 'rejected' end,
         approval_note = case when p_approve then '' else btrim(p_note) end,
         approval_at   = now()
   where id = p_service_id
  returning * into svc;
  if not found then
    raise exception 'الخدمةُ غير موجودة';
  end if;

  if p_approve then
    perform public.notify_provider(svc.provider_id, 'account',
      'وافقت الإدارةُ على خدمتك',
      '«' || svc.title || '» ظاهرةٌ للعملاء الآن.',
      jsonb_build_object('service_id', svc.id));
  else
    perform public.notify_provider(svc.provider_id, 'account',
      'لم تُقبل خدمتُك',
      '«' || svc.title || '» — ' || btrim(p_note) || ' ويمكنك تعديلها فتعود للمراجعة.',
      jsonb_build_object('service_id', svc.id));
  end if;
  return svc;
end $$;

revoke execute on function public.api_admin_review_service(uuid, boolean, text) from public, anon;
grant execute on function public.api_admin_review_service(uuid, boolean, text) to authenticated;

-- ----------------------------------------------------------------------------
--  ٩. ما ينتظر الإدارةَ — من كلّ المزوّدين، مع أقسام صاحبه
-- ----------------------------------------------------------------------------
--  دالّةٌ لا عرض: `v_admin_services` بُني بـ`s.*` فلا يرى الأعمدةَ الجديدة.
create or replace function public.api_admin_service_reviews()
returns table (
  id uuid, title text, price numeric, approval text, approval_note text,
  category_id uuid, category_name text,
  provider_id uuid, provider_name text, provider_categories text,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select s.id, s.title, s.price, s.approval, s.approval_note,
         s.category_id, coalesce(c.name, ''),
         s.provider_id, coalesce(nullif(p.business_name, ''), p.full_name, ''),
         coalesce((select string_agg(c2.name, '، ' order by c2.sort_order)
                     from public.provider_categories pc
                     join public.service_categories c2 on c2.id = pc.category_id
                    where pc.provider_id = s.provider_id), ''),
         s.created_at
    from public.provider_services s
    join public.service_providers p on p.id = s.provider_id
    left join public.service_categories c on c.id = s.category_id
   where s.approval <> 'approved'
     and public.is_admin()
   order by (s.approval = 'pending') desc, s.created_at desc
$$;

revoke execute on function public.api_admin_service_reviews() from public, anon;
grant execute on function public.api_admin_service_reviews() to authenticated;

commit;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
--  تحقّق: ما ينتظر الموافقةَ الآن
-- ----------------------------------------------------------------------------
select coalesce(nullif(p.business_name, ''), p.full_name) as "مقدّم الخدمة",
       s.title    as "الخدمة",
       c.name     as "قسمُها",
       s.approval as "الحال"
  from public.provider_services s
  join public.service_providers p on p.id = s.provider_id
  join public.service_categories c on c.id = s.category_id
 where s.approval <> 'approved'
 order by 1, 2;
