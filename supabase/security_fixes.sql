-- إصلاحات الفحص الأمني الثاني — لصقةٌ واحدة للقاعدة الحيّة، بلا حذف بيانات.
-- المصدر مركّب من الملفات الأصلية بواسطة tool/security_sql.mjs (buildFixes).
-- شغّله بعد security_hardening.sql وphone_verify_attempts.sql. آمنٌ عند التكرار.
begin;

do $$
begin
  if to_regprocedure('public.otp_claim_verify(uuid,text)') is null then
    raise exception 'الصق phone_verify_attempts.sql أوّلاً — دالّةُ الرسائل صارت تردّ التحقّقَ بدون حدّ المحاولات';
  end if;
  if to_regprocedure('public.can_write_area(text)') is null
     or to_regclass('public.coupons') is null
     or to_regprocedure('public.api_create_booking(uuid,date,time,uuid,integer,text,text,boolean,text,numeric,numeric)') is null then
    raise exception 'تحتاج roles.sql وcoupons.sql وlocation.sql قبل هذا الملف';
  end if;
end;
$$;

-- Source: policies.sql
drop policy if exists conversations_parties_write on public.conversations;


-- Source: chat.sql
create or replace function public.api_open_conversation(
  p_provider_id uuid,
  p_booking_id  uuid default null
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me            uuid := public.current_app_user();
  my_name       text;
  provider_name text;
  found         uuid;
begin
  if me is null then
    raise exception 'لا يمكن فتح محادثة قبل إكمال حسابك.' using errcode = '42501';
  end if;

  select p.business_name into provider_name
  from public.service_providers p
  where p.id = p_provider_id and p.status = 'verified';
  if provider_name is null then
    raise exception 'مقدّم الخدمة غير موجود أو غير موثّق.' using errcode = 'P0002';
  end if;

  -- **والحجزُ المربوطُ حجزُه هو، ومع هذا المزوّد.** كان يُقبل أيُّ معرّف،
  -- فيُربط بمحادثته حجزُ غيره.
  if p_booking_id is not null and not exists (
    select 1 from public.bookings b
    where b.id = p_booking_id and b.user_id = me and b.provider_id = p_provider_id
  ) then
    raise exception 'الحجز غير موجود أو ليس لك.' using errcode = 'P0002';
  end if;

  select u.full_name into my_name from public.app_users u where u.id = me;

  -- محادثةٌ واحدة لكل (عميل، مقدّم خدمة) بصرف النظر عن الحجز: من راسل صاحب
  -- القاعة قبل الحجز ثم حجز لا يبدأ من جديد، ولا يبحث عن كلامه في خيطين.
  select c.id into found
  from public.conversations c
  where c.user_id = me and c.provider_id = p_provider_id
  order by c.last_message_at desc
  limit 1;

  if found is not null then
    -- الحجز يُربط أوّلَ مرّةٍ يُذكر فيها ولا يُبدَّل بعدها.
    if p_booking_id is not null then
      update public.conversations set booking_id = p_booking_id
      where id = found and booking_id is null;
    end if;
    return found;
  end if;

  insert into public.conversations (booking_id, user_id, user_name, provider_id, provider_name)
  values (p_booking_id, me, coalesce(my_name, ''), p_provider_id, provider_name)
  returning id into found;
  return found;
end $$;

-- Source: coupons.sql
create table if not exists public.coupon_checks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.app_users (id) on delete cascade,
  code       text not null,
  ok         boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists coupon_checks_user_time_idx
  on public.coupon_checks (user_id, created_at desc);
alter table public.coupon_checks enable row level security;
revoke all on public.coupon_checks from public, anon, authenticated;

-- Source: coupons.sql
create or replace function public.api_check_coupon(
  p_code       text,
  p_service_id uuid
)
returns table (code text, description text, discount numeric)
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  c        public.coupons;
  svc      record;
  settings public.app_settings;
  comm     numeric(5, 2);
  misses   integer;
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  -- عشرةُ أكوادٍ خاطئةٍ في ربع ساعة — ثمّ انتظار.
  select count(*) into misses
    from public.coupon_checks k
   where k.user_id = me and not k.ok and k.created_at > now() - interval '15 minutes';
  if misses >= 10 then
    raise exception 'جرّبتَ أكواداً كثيرة. انتظر ربع ساعة ثمّ أعد المحاولة.';
  end if;

  select * into c from public.coupons k
   where k.code = upper(btrim(p_code));
  if not found then
    insert into public.coupon_checks (user_id, code, ok)
    values (me, upper(btrim(coalesce(p_code, ''))), false);
    return;
  end if;

  select s.price, s.category_id, p.commission_percent as provider_commission
    into svc
    from public.provider_services s
    join public.service_providers p on p.id = s.provider_id
   where s.id = p_service_id;
  if not found then
    raise exception 'الخدمة غير موجودة';
  end if;

  select * into settings from public.app_settings where id = 1;
  comm := coalesce(svc.provider_commission, settings.commission_percent);

  return query
    select c.code,
           c.description,
           public.coupon_discount(
             c, me, svc.price, svc.category_id,
             round(svc.price * comm / 100.0, 2));

  -- بعد الحساب لا قبله: كودٌ موجودٌ لا ينطبق يرمي أعلاه، فلا يأذن بحجز.
  insert into public.coupon_checks (user_id, code, ok) values (me, c.code, true);
end;
$$;

-- Source: location.sql
create or replace function public.api_create_booking(
  p_service_id   uuid,
  p_event_date   date,
  p_event_time   time default null,
  p_plan_id      uuid default null,
  p_guests_count integer default 0,
  p_address      text default '',
  p_notes        text default '',
  p_pay_full     boolean default false,
  p_coupon_code  text default '',
  p_latitude     numeric default null,
  p_longitude    numeric default null
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  me         uuid := public.current_app_user();
  me_row     public.app_users;
  svc        record;
  settings   public.app_settings;
  booking    public.bookings;
  due        numeric(12,2);
  commission numeric(5,2);
  comm_base  numeric(12,2);
  coupon     public.coupons;
  discount   numeric(12,2) := 0;
  lat        numeric(9,6) := round(p_latitude::numeric,  6);
  lng        numeric(9,6) := round(p_longitude::numeric, 6);
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if p_event_date < current_date then
    raise exception 'لا يمكن الحجز في تاريخ مضى';
  end if;

  if (lat is null) <> (lng is null) then
    raise exception 'الموقع يحتاج خطَّي الطول والعرض معاً';
  end if;

  select u.* into me_row from public.app_users u where u.id = me;
  if me_row.status <> 'active' then
    raise exception 'حسابك غير مفعّل حالياً';
  end if;

  select s.id, s.title, s.price, s.deposit_percent, s.category_id, s.provider_id,
         s.is_active, c.name as category_name, p.business_name, p.status as provider_status,
         p.commission_percent as provider_commission,
         coalesce(pol.rules, '[]'::jsonb) as rules
  into svc
  from public.provider_services s
  join public.service_providers p on p.id = s.provider_id
  join public.service_categories c on c.id = s.category_id
  left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id
  where s.id = p_service_id;

  if not found then
    raise exception 'الخدمة غير موجودة';
  end if;
  if not svc.is_active or svc.provider_status <> 'verified' then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';
  end if;

  if exists (
    select 1 from public.provider_availability a
    where a.provider_id = svc.provider_id and a.day = p_event_date and a.is_blocked
  ) then
    raise exception 'مقدّم الخدمة غير متاح في هذا التاريخ';
  end if;

  if p_plan_id is not null and not exists (
    select 1 from public.wedding_plans w where w.id = p_plan_id and w.user_id = me
  ) then
    raise exception 'خطة العرس غير موجودة';
  end if;

  select * into settings from public.app_settings where id = 1;
  commission := coalesce(svc.provider_commission, settings.commission_percent);
  comm_base  := round(svc.price * commission / 100.0, 2);

  if btrim(coalesce(p_coupon_code, '')) <> '' then
    -- **قبل البحث عن الكود:** وإلّا صار «هذا الكود غير صحيح» هنا جوابَ
    -- تخمينٍ بلا حدّ. والحدُّ في `api_check_coupon` (`coupons.sql`).
    if not exists (
      select 1 from public.coupon_checks k
       where k.user_id = me and k.ok
         and k.code = upper(btrim(p_coupon_code))
         and k.created_at > now() - interval '1 day'
    ) then
      raise exception 'تحقّق من الكود أولاً';
    end if;

    select * into coupon from public.coupons k
     where k.code = upper(btrim(p_coupon_code))
     for update;
    if not found then
      raise exception 'هذا الكود غير صحيح';
    end if;
    discount := public.coupon_discount(
      coupon, me, svc.price, svc.category_id, comm_base);
  end if;

  due := case
    when p_pay_full then svc.price
    else round(svc.price * svc.deposit_percent / 100.0, 2)
  end;
  due := greatest(due - discount, 0);

  insert into public.bookings (
    reference, user_id, user_name, provider_id, provider_name,
    service_id, service_title, category_id, category_name, plan_id,
    event_date, event_time, governorate, address, guests_count, notes,
    status, total_price, deposit_amount, paid_amount,
    commission_percent, commission_amount, cancellation_rules,
    coupon_code, discount_amount, latitude, longitude
  ) values (
    'BK-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    svc.id, svc.title, svc.category_id, svc.category_name, p_plan_id,
    p_event_date, p_event_time, me_row.governorate, p_address, p_guests_count, p_notes,
    'pending_provider', svc.price, round(svc.price * svc.deposit_percent / 100.0, 2), 0,
    commission, 0, svc.rules,
    coalesce(coupon.code, ''), discount, lat, lng
  ) returning * into booking;

  if discount > 0 then
    insert into public.coupon_redemptions (coupon_id, user_id, booking_id, code, amount)
      values (coupon.id, me, booking.id, coupon.code, discount);
    update public.coupons set used_count = used_count + 1 where id = coupon.id;
  end if;

  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, platform_share, net_amount, status
  ) values (
    'TRX-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    booking.id, booking.reference,
    case when p_pay_full then 'full' else 'deposit' end,
    case when p_pay_full then 'سداد كامل — ' else 'عربون حجز — ' end || svc.category_name
      || case when discount > 0 then ' (كوبون ' || coupon.code || ')' else '' end,
    due,
    greatest(round(due * commission / 100.0, 2) - discount, 0),
    due - greatest(round(due * commission / 100.0, 2) - discount, 0),
    'pending'
  );

  perform public.notify_provider(
    svc.provider_id, 'booking', 'طلب حجز جديد',
    'وصلك طلب حجز جديد بانتظار ردّك.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- Source: policies.sql
do $$
declare
  cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
    into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'reviews'
     and column_name <> 'user_id';
  execute 'revoke select on public.reviews from anon';
  execute format('grant select (%s) on public.reviews to anon', cols);
end $$;

-- Source: document_guard.sql
create or replace function public.guard_provider_document()
returns trigger language plpgsql set search_path = public as $$
begin
  -- المراجِع: يقبل ويرفض ويكتب ملاحظته.
  if public.can_write_area('directory') then
    return new;
  end if;

  new.status      := 'pending';
  new.reviewed_at := null;
  new.note        := '';

  if new.file_url <> ''
     and (left(new.file_url, 37) <> new.provider_id::text || '/'
          or position('..' in new.file_url) > 0) then
    raise exception 'المستندُ خارجَ مجلّدك.' using errcode = '42501';
  end if;

  return new;
end $$;

drop trigger if exists guard_provider_document on public.provider_documents;
create trigger guard_provider_document
  before insert or update on public.provider_documents
  for each row execute function public.guard_provider_document();

notify pgrst, 'reload schema';
commit;
