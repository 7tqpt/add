-- ============================================================================
--  الموقع على الخريطة: نقطةٌ مع العنوان، لا بدلاً منه
--
--  شغّله بعد `profile_extras.sql` و`coupons.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** لا `latitude` ولا `longitude` في القاعدة كلِّها. والعنوان
--  نصٌّ حرّ — «حي السنينة، بجانب مسجد النور، ثالث بيت» — يكفي من يعرف الحيّ
--  ولا يكفي مصوّراً من محافظةٍ أخرى يبحث عن البيت ليلة العرس.
--
--  ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
--
--  **١) النقطةُ تُضاف إلى العنوان ولا تحلّ محلّه.**
--
--  الإحداثيّاتُ تصلح للملاحة ولا تصلح للقراءة: من يقرأ «١٥٫٣٥، ٤٤٫٢٠» لا يعرف
--  أين هي. والنصُّ يبقى **إلزاميّاً** كما كان، والنقطةُ اختياريّةٌ فوقه. ولذلك
--  لا شرطَ `not null` على العمودين ولا حذفَ لشرط طول النصّ.
--
--  **٢) وإمّا الاثنان أو لا شيء.**
--
--  خطُّ عرضٍ بلا خطّ طولٍ ليس نصفَ موقع بل لا موقع — ويُرسم على خطّ غرينتش في
--  خليج غينيا. والقيدُ في القاعدة لا في الشيفرة: ثلاث شاشاتٍ تكتب هذين
--  العمودين، ويكفي أن تنسى واحدةٌ منها الثاني.
--
--  **٣) ولا تُقاس المسافةُ هنا.**
--
--  البحثُ «الأقرب إليّ» يحتاج `earthdistance` أو PostGIS وفهرساً مكانيّاً،
--  وكلاهما قرارٌ أكبرُ من عمودين. وما يُبنى اليوم هو **أن يصل المزوّد إلى
--  العرس** — وهو ما يُشتكى منه فعلاً. والبحثُ بالقرب يأتي على مخطّطٍ جاهزٍ
--  حين يُطلب، لا قبله.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- الأعمدة
--
-- `numeric(9,6)` لا `float`: ستُّ خاناتٍ عشرية تعني دقّةَ نحو عشرة سنتيمترات
-- عند خطّ الاستواء — أكثرُ ممّا يحتاجه بابُ بيت. والعشريُّ المضبوط يُخزَّن
-- ويُقرأ كما كُتب، بلا فروقٍ في آخر خانةٍ تظهر حين يُقارن رقمان.
-- ----------------------------------------------------------------------------
alter table public.user_addresses
  add column if not exists latitude  numeric(9, 6),
  add column if not exists longitude numeric(9, 6);

alter table public.bookings
  add column if not exists latitude  numeric(9, 6),
  add column if not exists longitude numeric(9, 6);

do $$ begin
  alter table public.user_addresses add constraint address_point_sane check (
    (latitude is null) = (longitude is null)
    and (latitude  is null or latitude  between  -90 and  90)
    and (longitude is null or longitude between -180 and 180));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.bookings add constraint booking_point_sane check (
    (latitude is null) = (longitude is null)
    and (latitude  is null or latitude  between  -90 and  90)
    and (longitude is null or longitude between -180 and 180));
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- api_save_address — بنقطةٍ اختيارية
--
-- **`drop` ثمّ `create`:** إضافةُ معاملٍ تُنشئ دالّةً ثانيةً بجانب الأولى لا
-- بديلاً عنها، فيصير النداءُ من التطبيق ملتبساً بين توقيعين.
-- ----------------------------------------------------------------------------
drop function if exists public.api_save_address(uuid, text, text, uuid, boolean);

create or replace function public.api_save_address(
  p_id             uuid default null,
  p_label          text default '',
  p_details        text default '',
  p_governorate_id uuid default null,
  p_default        boolean default false,
  p_latitude       numeric default null,
  p_longitude      numeric default null
)
returns setof public.user_addresses
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  gov  text;
  row_ public.user_addresses;
  lat  numeric(9, 6) := round(p_latitude::numeric,  6);
  lng  numeric(9, 6) := round(p_longitude::numeric, 6);
begin
  if me is null then raise exception 'سجّل الدخول أولاً'; end if;
  if length(btrim(coalesce(p_details, ''))) < 5 then
    raise exception 'اكتب العنوان بتفصيلٍ يكفي لِمن يصل إليه';
  end if;

  -- **يُردّ نصفُ الموقع هنا برسالةٍ تُقرأ** بدل أن يردّه القيدُ برسالةٍ لا
  -- يفهمها أحد. والقيدُ يبقى: هذه شاشةٌ واحدةٌ من ثلاثٍ تكتب العمودين.
  if (lat is null) <> (lng is null) then
    raise exception 'الموقع يحتاج خطَّي الطول والعرض معاً';
  end if;

  select g.name into gov from public.governorates g where g.id = p_governorate_id;

  if p_default then
    update public.user_addresses set is_default = false
     where user_id = me and is_default and id is distinct from p_id;
  end if;

  if p_id is null then
    insert into public.user_addresses
      (user_id, label, governorate_id, governorate, details, is_default,
       latitude, longitude)
    values (me, btrim(coalesce(p_label, '')), p_governorate_id,
            coalesce(gov, ''), btrim(p_details),
            p_default or not exists (
              select 1 from public.user_addresses where user_id = me),
            lat, lng)
    returning * into row_;
  else
    update public.user_addresses a
       set label          = btrim(coalesce(p_label, a.label)),
           governorate_id = coalesce(p_governorate_id, a.governorate_id),
           governorate    = coalesce(gov, a.governorate),
           details        = btrim(p_details),
           is_default     = p_default or a.is_default,
           -- **والنقطةُ تُمحى بإرسال فراغٍ لا تبقى إلى الأبد.** لو كُتبت
           -- `coalesce(lat, a.latitude)` لَما استطاع من وضع نقطةً خطأً أن
           -- يزيلها أبداً — يصحّحها ولا يحذفها.
           latitude       = lat,
           longitude      = lng
     where a.id = p_id and a.user_id = me
    returning * into row_;
    if not found then raise exception 'العنوان غير موجود'; end if;
  end if;

  return next row_;
end;
$$;

revoke all on function public.api_save_address(uuid, text, text, uuid, boolean, numeric, numeric) from public;
grant execute on function public.api_save_address(uuid, text, text, uuid, boolean, numeric, numeric) to authenticated;

-- ----------------------------------------------------------------------------
-- api_create_booking — بنقطةٍ اختيارية أيضاً
--
-- تُعاد كتابتها كما هي في `coupons.sql` إلّا في المعاملين ومكانَي كتابتهما.
-- ----------------------------------------------------------------------------
drop function if exists public.api_create_booking(
  uuid, date, time, uuid, integer, text, text, boolean, text);

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

revoke all on function public.api_create_booking(
  uuid, date, time, uuid, integer, text, text, boolean, text, numeric, numeric) from public;
grant execute on function public.api_create_booking(
  uuid, date, time, uuid, integer, text, text, boolean, text, numeric, numeric) to authenticated;

commit;
