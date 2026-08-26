-- ============================================================================
--  ما ينقص «حسابي»: الدور، والعناوين، وطرقُ الدفع، والإعدادات
--
--  شغّله **بعد `profile.sql`**. آمنٌ عند التكرار.
-- ============================================================================
--
--  **أربعةٌ كانت في لوحة التصميم ولا وجود لها في القاعدة**، فكانت صفوفاً
--  تُضغط ولا تفتح على شيء. وصفٌّ لا يفتح على شيءٍ أسوأ من صفٍّ غائب: يضغطه
--  المستخدم فيتعلّم أن التطبيق مكسور.
--
--  ولكلٍّ منها مستهلكٌ قائمٌ في التطبيق لا شاشةٌ معلّقة في الفراغ:
--
--    • الدور     → شارةُ «حسابي»، وهي اليوم تقول «عميل» لعروسٍ وعريس.
--    • العنوان   → `bookings.address` — حقلٌ يكتبه العميل **في كل حجز**.
--    • طرقُ الدفع → `payments.sender_ref` — رقمٌ يكتبه **مع كل حوالة**.
--    • الإعدادات → حذفُ الحساب، وهو شرطُ متجر Google للنشر.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. الدور: عروسٌ أو عريس
--
-- **يُسأل عنه اليوم ثمّ يُنسى.** «اختر نوع الحساب» تحفظ الاختيار في ذاكرة
-- التشغيل وتستعمله لسَوق مقدّم الخدمة إلى ملفّه، ثمّ يذهب. فمن قال «أنا عروس»
-- وجد شارته تقول «عميل».
--
-- والفراغُ حالٌ صحيحة لا نقص: من سجّل قبل هذا العمود، ومن جاء ليبيع لا ليعرس.
-- ----------------------------------------------------------------------------
alter table public.app_users
  add column if not exists wedding_role text not null default '';

alter table public.app_users drop constraint if exists app_users_wedding_role;
alter table public.app_users
  add constraint app_users_wedding_role
  check (wedding_role in ('', 'bride', 'groom'));

-- ----------------------------------------------------------------------------
-- ٢. العناوين
--
-- `bookings.address` حقلٌ نصّيٌّ يكتبه العميل في **كل** حجز — وعنوانُ بيت
-- العرس واحدٌ لا يتغيّر. فمن حجز قاعةً ومصوّراً وكوشةً كتبه ثلاث مرّات،
-- وأخطأ في إحداها.
--
-- والمحافظةُ مرتبطةٌ بالجدول لا مكتوبةً نصّاً: اسمُ المحافظة يُشتقّ منها،
-- فلا يكتب أحدٌ «صنعا» و«صنعاء» و«أمانة العاصمة» لمكانٍ واحد.
-- ----------------------------------------------------------------------------
create table if not exists public.user_addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.app_users (id) on delete cascade,
  -- «بيت العروس»، «القاعة»، «بيت العريس» — اسمٌ يميّزه في قائمةٍ من ثلاثة.
  label          text not null default '',
  governorate_id uuid references public.governorates (id) on delete set null,
  governorate    text not null default '',
  -- المنطقة والشارع والعلامة المميّزة — نصٌّ حرّ، فعناوين اليمن ليست أرقاماً.
  details        text not null,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  constraint address_details_len check (length(btrim(details)) between 5 and 400),
  constraint address_label_len   check (length(btrim(label)) <= 40)
);

create index if not exists user_addresses_user_idx
  on public.user_addresses (user_id, is_default desc, created_at desc);

-- **واحدٌ افتراضيٌّ لا أكثر.** فهرسٌ فريدٌ جزئيّ يمنع اثنين — ولو مُنع بالشيفرة
-- وحدها لَمرّ اثنان عند ضغطتين متسارعتين، ثمّ لا يعرف التطبيق أيَّهما يملأ به
-- نموذج الحجز.
create unique index if not exists user_addresses_one_default
  on public.user_addresses (user_id) where is_default;

alter table public.user_addresses enable row level security;

drop policy if exists "addresses owner reads" on public.user_addresses;
create policy "addresses owner reads" on public.user_addresses
  for select to authenticated using (user_id = public.current_app_user());

drop policy if exists "addresses owner writes" on public.user_addresses;
create policy "addresses owner writes" on public.user_addresses
  for insert to authenticated with check (user_id = public.current_app_user());

drop policy if exists "addresses owner edits" on public.user_addresses;
create policy "addresses owner edits" on public.user_addresses
  for update to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

drop policy if exists "addresses owner deletes" on public.user_addresses;
create policy "addresses owner deletes" on public.user_addresses
  for delete to authenticated using (user_id = public.current_app_user());

-- **ولا سياسةَ قراءةٍ لمقدّم الخدمة ولا للإدارة، وهذا مقصود.** عنوانُ بيت
-- العميل يصل مقدّمَ الخدمة **في الحجز** إذا حجز عنده — وهو نصٌّ يُنسخ إلى
-- `bookings.address` عند الحجز لا رابطٌ إلى دفتره. فمن لم يحجز عنده لا يرى
-- شيئاً، ودفترُ عناوين الناس لا يُفتح لأحد.

-- ----------------------------------------------------------------------------
-- ٣. طرقُ الدفع — **أرقامُ المستخدم التي يُحوّل منها**
--
-- ولا بطاقاتٍ ولا أرقامَ سرّيّة: الدفعُ في المنصّة حوالةٌ يرسلها العميل من
-- محفظته ثمّ يُبلّغ برقمها، فتؤكّدها الإدارة. فما يُحفظ هنا هو **رقمُ محفظته
-- هو**، ليملأ به `sender_ref` بدل أن يكتبه مع كل حوالة.
--
-- **ولا يُحفظ منه ما يُدفع به.** لا رقمَ بطاقةٍ ولا رمزَ تحقّقٍ ولا كلمةَ مرور
-- محفظة — لا شيء ممّا لو سُرّب أخرج مالاً. وهذه أرقامٌ يعطيها صاحبها لمن
-- يحوّل له أصلاً.
-- ----------------------------------------------------------------------------
create table if not exists public.user_payment_methods (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.app_users (id) on delete cascade,
  method      text not null check (method in ('jawali', 'kuraimi', 'bank', 'cash')),
  -- اسمُ صاحب المحفظة: الحوالة تُراجَع بالاسم والرقم معاً.
  holder_name text not null default '',
  account_ref text not null,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  constraint payment_ref_len check (length(btrim(account_ref)) between 4 and 60),
  constraint payment_holder_len check (length(btrim(holder_name)) <= 80),
  -- ولا رقمان متطابقان لوسيلةٍ واحدة عند صاحبٍ واحد.
  constraint payment_method_unique unique (user_id, method, account_ref)
);

create index if not exists user_payment_methods_user_idx
  on public.user_payment_methods (user_id, is_default desc, created_at desc);

create unique index if not exists user_payment_methods_one_default
  on public.user_payment_methods (user_id) where is_default;

alter table public.user_payment_methods enable row level security;

drop policy if exists "wallets owner reads" on public.user_payment_methods;
create policy "wallets owner reads" on public.user_payment_methods
  for select to authenticated using (user_id = public.current_app_user());

drop policy if exists "wallets owner writes" on public.user_payment_methods;
create policy "wallets owner writes" on public.user_payment_methods
  for insert to authenticated with check (user_id = public.current_app_user());

drop policy if exists "wallets owner edits" on public.user_payment_methods;
create policy "wallets owner edits" on public.user_payment_methods
  for update to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

drop policy if exists "wallets owner deletes" on public.user_payment_methods;
create policy "wallets owner deletes" on public.user_payment_methods
  for delete to authenticated using (user_id = public.current_app_user());

-- **ولا أحدَ غيرُ صاحبها يقرؤها — ولا الإدارة.** ما تحتاجه الإدارة لمراجعة
-- الحوالة مكتوبٌ في `payments.sender_ref` وقتَ الإبلاغ؛ ودفترُ محافظ الناس
-- ليس من شأنها.

-- ----------------------------------------------------------------------------
-- ٤. إعدادات المستخدم
--
-- صفٌّ واحدٌ لكل مستخدم. والإشعاراتُ أوّلُ ما يُطفأ: من وصلته عشرةُ إشعاراتٍ
-- في يومٍ ولم يجد أين يوقفها حذف التطبيق.
-- ----------------------------------------------------------------------------
create table if not exists public.user_settings (
  user_id        uuid primary key references public.app_users (id) on delete cascade,
  push_enabled   boolean not null default true,
  -- إشعاراتُ العروض والإعلانات — تُفصل عن إشعارات الحجوزات: من أطفأ الدعاية
  -- لا يقصد أن يفوته «قُبل حجزك».
  promos_enabled boolean not null default true,
  updated_at     timestamptz not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists "settings owner reads" on public.user_settings;
create policy "settings owner reads" on public.user_settings
  for select to authenticated using (user_id = public.current_app_user());

drop policy if exists "settings owner writes" on public.user_settings;
create policy "settings owner writes" on public.user_settings
  for insert to authenticated with check (user_id = public.current_app_user());

drop policy if exists "settings owner edits" on public.user_settings;
create policy "settings owner edits" on public.user_settings
  for update to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

commit;

-- ============================================================================
--  الدوالّ
-- ============================================================================
begin;

-- ---- الدور ------------------------------------------------------------------
create or replace function public.api_set_wedding_role(p_role text)
returns setof public.app_users
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  if coalesce(p_role, '') not in ('', 'bride', 'groom') then
    raise exception 'دورٌ غير معروف';
  end if;
  return query
    update public.app_users u set wedding_role = coalesce(p_role, '')
     where u.auth_user_id = me
    returning u.*;
end $$;

-- ---- العناوين ---------------------------------------------------------------
create or replace function public.api_my_addresses()
returns setof public.user_addresses
language sql stable security definer set search_path = public as $$
  select * from public.user_addresses
   where user_id = public.current_app_user()
   order by is_default desc, created_at desc
$$;

-- يحفظ عنواناً — جديداً أو تعديلاً على قائم.
create or replace function public.api_save_address(
  p_id             uuid default null,
  p_label          text default '',
  p_details        text default '',
  p_governorate_id uuid default null,
  p_default        boolean default false
)
returns setof public.user_addresses
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  gov  text;
  row_ public.user_addresses;
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  if length(btrim(coalesce(p_details, ''))) < 5 then
    raise exception 'اكتب العنوان بتفصيلٍ يكفي لِمن يصل إليه';
  end if;

  select g.name into gov from public.governorates g where g.id = p_governorate_id;

  -- **يُنزَع الافتراضيُّ عن غيره قبل أن يُوضع، وفي المعاملة نفسها.** الفهرسُ
  -- الفريد يردّ الثانيَ لو وُضع قبل النزع.
  if p_default then
    update public.user_addresses set is_default = false
     where user_id = me and is_default and id is distinct from p_id;
  end if;

  if p_id is null then
    insert into public.user_addresses
      (user_id, label, governorate_id, governorate, details, is_default)
    values (me, btrim(coalesce(p_label, '')), p_governorate_id,
            coalesce(gov, ''), btrim(p_details),
            -- أوّلُ عنوانٍ يُحفظ افتراضيٌّ بلا سؤال: قائمةٌ من واحدٍ بلا
            -- افتراضيٍّ تجعل نموذج الحجز لا يجد ما يملأ به.
            p_default or not exists (
              select 1 from public.user_addresses where user_id = me))
    returning * into row_;
  else
    update public.user_addresses a
       set label          = btrim(coalesce(p_label, a.label)),
           governorate_id = coalesce(p_governorate_id, a.governorate_id),
           governorate    = coalesce(gov, a.governorate),
           details        = btrim(p_details),
           is_default     = p_default or a.is_default
     where a.id = p_id and a.user_id = me
    returning * into row_;
    if row_.id is null then raise exception 'لا عنوان بهذا المعرّف'; end if;
  end if;

  return next row_;
end $$;

create or replace function public.api_delete_address(p_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  gone boolean;
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  delete from public.user_addresses where id = p_id and user_id = me;
  gone := found;

  -- **ولا تبقى القائمةُ بلا افتراضيّ.** من حذف افتراضيَّه ثمّ فتح نموذج
  -- الحجز كان لا يجد ما يملأ به وعنده عنوانان.
  if gone and not exists (
    select 1 from public.user_addresses where user_id = me and is_default
  ) then
    update public.user_addresses set is_default = true
     where id = (select id from public.user_addresses
                  where user_id = me order by created_at desc limit 1);
  end if;
  return gone;
end $$;

-- ---- طرقُ الدفع -------------------------------------------------------------
create or replace function public.api_my_payment_methods()
returns setof public.user_payment_methods
language sql stable security definer set search_path = public as $$
  select * from public.user_payment_methods
   where user_id = public.current_app_user()
   order by is_default desc, created_at desc
$$;

create or replace function public.api_save_payment_method(
  p_id          uuid default null,
  p_method      text default 'jawali',
  p_account_ref text default '',
  p_holder_name text default '',
  p_default     boolean default false
)
returns setof public.user_payment_methods
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  row_ public.user_payment_methods;
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  if coalesce(p_method, '') not in ('jawali', 'kuraimi', 'bank', 'cash') then
    raise exception 'وسيلةٌ غير معروفة';
  end if;
  if length(btrim(coalesce(p_account_ref, ''))) < 4 then
    raise exception 'اكتب رقم المحفظة أو الحساب';
  end if;

  if p_default then
    update public.user_payment_methods set is_default = false
     where user_id = me and is_default and id is distinct from p_id;
  end if;

  if p_id is null then
    insert into public.user_payment_methods
      (user_id, method, account_ref, holder_name, is_default)
    values (me, p_method, btrim(p_account_ref), btrim(coalesce(p_holder_name, '')),
            p_default or not exists (
              select 1 from public.user_payment_methods where user_id = me))
    returning * into row_;
  else
    update public.user_payment_methods m
       set method      = p_method,
           account_ref = btrim(p_account_ref),
           holder_name = btrim(coalesce(p_holder_name, m.holder_name)),
           is_default  = p_default or m.is_default
     where m.id = p_id and m.user_id = me
    returning * into row_;
    if row_.id is null then raise exception 'لا وسيلةَ بهذا المعرّف'; end if;
  end if;

  return next row_;
end $$;

create or replace function public.api_delete_payment_method(p_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  gone boolean;
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  delete from public.user_payment_methods where id = p_id and user_id = me;
  gone := found;
  if gone and not exists (
    select 1 from public.user_payment_methods where user_id = me and is_default
  ) then
    update public.user_payment_methods set is_default = true
     where id = (select id from public.user_payment_methods
                  where user_id = me order by created_at desc limit 1);
  end if;
  return gone;
end $$;

-- ---- الإعدادات --------------------------------------------------------------
create or replace function public.api_my_settings()
returns setof public.user_settings
language sql stable security definer set search_path = public as $$
  select * from public.user_settings where user_id = public.current_app_user()
$$;

create or replace function public.api_save_settings(
  p_push   boolean default null,
  p_promos boolean default null
)
returns setof public.user_settings
language plpgsql security definer set search_path = public as $$
declare me uuid := public.current_app_user();
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  return query
    insert into public.user_settings (user_id, push_enabled, promos_enabled, updated_at)
    values (me, coalesce(p_push, true), coalesce(p_promos, true), now())
    on conflict (user_id) do update
      set push_enabled   = coalesce(p_push,   public.user_settings.push_enabled),
          promos_enabled = coalesce(p_promos, public.user_settings.promos_enabled),
          updated_at     = now()
    returning *;
end $$;

-- ---- حذفُ الحساب ------------------------------------------------------------
--
-- **شرطُ متجر Google للنشر**، ولا وجود له في المنصّة إلى اليوم.
--
-- ويُحذف صفُّ المصادقة، فيتسلسل الحذفُ إلى `app_users` ومنه إلى العناوين
-- والمحافظ والإعدادات والخطّة والمفضّلة.
--
-- **وما لا يُحذف يُقطع نسبُه لا يُمحى:** الحجوزات والمدفوعات والفواتير
-- `on delete set null` — سجلٌّ ماليٌّ يخصّ الطرف الآخر أيضاً، ومحوُه يمحو
-- دليلَ مقدّم الخدمة على بيعٍ تمّ ومالٍ قُبض. وهذا يُقال للمستخدم صراحةً في
-- الشاشة قبل أن يضغط.
create or replace function public.api_delete_my_account()
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := auth.uid();
  mine uuid := public.current_app_user();
  owed numeric;
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;

  -- **ولا يُحذف من عليه حجزٌ قائم.** حسابٌ يختفي وتحته عربونٌ مدفوعٌ وحجزٌ
  -- لم يُنفَّذ يترك مقدّمَ الخدمة أمام موعدٍ لا يعرف صاحبه، والإدارةَ أمام
  -- مالٍ لا تعرف لمن تردّه.
  select count(*) into owed
    from public.bookings b
   where b.user_id = mine
     and b.status in ('pending_provider', 'confirmed');
  if owed > 0 then
    raise exception 'لديك % حجزاً قائماً — ألغِها أو انتظر تنفيذها قبل حذف الحساب', owed;
  end if;

  delete from auth.users where id = me;
  return true;
end $$;

revoke all on function public.api_delete_my_account() from public;

grant execute on function public.api_set_wedding_role(text)                    to authenticated;
grant execute on function public.api_my_addresses()                            to authenticated;
grant execute on function public.api_save_address(uuid, text, text, uuid, boolean) to authenticated;
grant execute on function public.api_delete_address(uuid)                      to authenticated;
grant execute on function public.api_my_payment_methods()                      to authenticated;
grant execute on function public.api_save_payment_method(uuid, text, text, text, boolean) to authenticated;
grant execute on function public.api_delete_payment_method(uuid)               to authenticated;
grant execute on function public.api_my_settings()                             to authenticated;
grant execute on function public.api_save_settings(boolean, boolean)           to authenticated;
grant execute on function public.api_delete_my_account()                       to authenticated;

commit;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'عمودُ الدور' as البند,
       case when exists (
         select 1 from information_schema.columns
          where table_name = 'app_users' and column_name = 'wedding_role')
       then '✅' else '❌' end as الحال
union all
select 'جدولُ العناوين',
       case when to_regclass('public.user_addresses') is not null then '✅' else '❌' end
union all
select 'واحدٌ افتراضيٌّ لا أكثر (عناوين)',
       case when exists (select 1 from pg_indexes
                          where indexname = 'user_addresses_one_default')
       then '✅' else '❌' end
union all
select 'جدولُ طرق الدفع',
       case when to_regclass('public.user_payment_methods') is not null then '✅' else '❌' end
union all
select 'جدولُ الإعدادات',
       case when to_regclass('public.user_settings') is not null then '✅' else '❌' end
union all
select 'حذفُ الحساب — شرطُ Google Play',
       case when exists (select 1 from pg_proc where proname = 'api_delete_my_account')
       then '✅' else '❌' end
union all
select 'ولا يقرأ دفترَ عناوينك أحدٌ غيرك',
       case when (select count(*) from pg_policies
                   where tablename = 'user_addresses') = 4
       then '✅' else '❌ راجع السياسات' end;
