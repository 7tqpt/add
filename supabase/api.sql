-- ============================================================================
--  الـ API — شغّلها بعد schema.sql و policies.sql
--
--  كل ما لا يجوز أن يمليه التطبيق يعيش هنا: السعر، العربون، العمولة، وشروط
--  الانتقال بين الحالات. التطبيق يطلب «احجز هذه الخدمة»، والخادم هو من يقرر
--  كم تُكلّف ومتى يجوز الحجز.
--
--  تُستدعى من التطبيقين هكذا:
--    const { data, error } = await supabase.rpc('api_create_booking', { … })
--
--  كل الدوال security definer لأنها تكتب في جداول تمنع RLS الكتابة المباشرة
--  فيها؛ ولذلك تبدأ كل واحدة بالتحقق من هوية المتصل بنفسها.
-- ============================================================================

-- ============================================================================
--  طرق العرض العامة — ما يقرؤه التطبيق للبحث والاستكشاف
-- ============================================================================

-- ----------------------------------------------------------------------------
-- الخدمات المعروضة، مضمومة إلى مقدّمها وقسمها.
-- security_invoker: تُطبَّق سياسات RLS على المتصل لا على منشئ الطريقة، فلا
-- تتسرّب خدمة غير مفعّلة أو مقدّم غير موثّق.
-- ----------------------------------------------------------------------------
-- **`drop` ثم `create` لا `create or replace`:** الثانية ترفض أي تغييرٍ في
-- الأعمدة غير الزيادة في الآخر، فكانت إعادةُ تشغيل هذا الملف على قاعدةٍ
-- شُغِّل عليها `service_media.sql` تسقط بـ«cannot drop columns from view».
--
-- **وأثرُ ذلك يجب أن يُعرف:** هذا الملف يبني الطريقة الأساسية بلا أعمدة
-- الوسائط، فمن أعاده بعد `service_media.sql` فقَدَ الغلافَ والعلامات —
-- ويستردّها بإعادة `service_media.sql` بعده. ولذلك ترتيبُ الملفات في
-- `README` ليس زينة.
drop view if exists public.v_services;

create view public.v_services
with (security_invoker = true) as
select
  s.id,
  s.title,
  s.description,
  s.price,
  s.price_to,
  s.unit,
  s.deposit_percent,
  s.duration_minutes,
  s.attributes,
  s.images,
  s.category_id,
  c.name  as category_name,
  c.slug  as category_slug,
  s.provider_id,
  p.business_name as provider_name,
  p.governorate   as provider_governorate,
  p.rating        as provider_rating,
  p.reviews_count as provider_reviews_count,
  p.is_featured   as provider_is_featured,
  pol.name  as cancellation_policy_name,
  pol.rules as cancellation_rules,
  -- التوثيق يأتي مع صفّ الخدمة: القائمة عشرون بطاقة، ونداءٌ لكل مزوّدٍ فيها
  -- عشرون طلباً على شبكة جوالٍ يمنية. و`verified_at` لا `status`: الطريقة
  -- العامة لا تُظهر العمود الثاني أصلاً.
  (p.verified_at is not null) as provider_verified
from public.provider_services s
join public.service_providers p on p.id = s.provider_id
join public.service_categories c on c.id = s.category_id
left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id;

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة الظاهرون، مع أقسامهم مجمّعة.
-- ----------------------------------------------------------------------------
drop view if exists public.v_providers;

create view public.v_providers
with (security_invoker = true) as
select
  p.id,
  p.business_name,
  p.full_name,
  p.bio,
  p.logo_path,
  p.governorate,
  p.coverage_areas,
  p.rating,
  p.reviews_count,
  p.completed_bookings,
  p.is_featured,
  p.verified_at,
  coalesce(
    (select array_agg(c.name order by c.sort_order)
     from public.provider_categories pc
     join public.service_categories c on c.id = pc.category_id
     where pc.provider_id = p.id),
    '{}'
  ) as categories
from public.service_providers p;

-- ----------------------------------------------------------------------------
-- ملخّص خطة العرس: الإجمالي والمدفوع والمتبقي، محسوبة من الحجوزات لا مخزّنة.
-- الوثيقة تطلب هذه اللوحة بالضبط في خاصية «خطة العرس».
-- ----------------------------------------------------------------------------
-- و`drop` ثم `create` للسبب نفسه: `apply.sql` يستبدل هذه الطريقة بنسخةٍ أوسع،
-- فكانت إعادةُ هذا الملف بعده تسقط. ومن أعاده استردّ الأوسعَ بإعادة `apply.sql`.
drop view if exists public.v_plan_summary;

create view public.v_plan_summary
with (security_invoker = true) as
select
  pl.id as plan_id,
  pl.user_id,
  pl.title,
  pl.wedding_date,
  pl.governorate,
  pl.guests_count,
  pl.budget,
  pl.status,
  count(b.id) filter (where b.status <> 'cancelled')          as services_count,
  coalesce(sum(b.total_price)    filter (where b.status not in ('cancelled','rejected')), 0) as total_cost,
  coalesce(sum(b.paid_amount)    filter (where b.status not in ('cancelled','rejected')), 0) as paid_amount,
  coalesce(sum(b.total_price - b.paid_amount)
           filter (where b.status not in ('cancelled','rejected')), 0) as remaining_amount
from public.wedding_plans pl
left join public.bookings b on b.plan_id = pl.id
group by pl.id;

-- ============================================================================
--  دوال العميل
-- ============================================================================

-- ----------------------------------------------------------------------------
-- api_register_profile — يربط حساب المصادقة بملف مستخدم في المنصة.
-- يُستدعى مرة واحدة بعد أول تسجيل دخول.
-- ----------------------------------------------------------------------------
create or replace function public.api_register_profile(
  p_full_name   text,
  p_phone       text default '',
  p_governorate text default '',
  p_platform    text default 'android'
)
returns public.app_users
language plpgsql security definer set search_path = public as $$
declare
  existing public.app_users;
  gov_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into existing from public.app_users where auth_user_id = auth.uid();
  if found then
    return existing;
  end if;

  select id into gov_id from public.governorates where name = p_governorate;

  insert into public.app_users
    (auth_user_id, full_name, email, phone, platform, governorate_id, governorate, status)
  values
    (auth.uid(), p_full_name,
     coalesce((select email from auth.users where id = auth.uid()), ''),
     p_phone, p_platform, gov_id, p_governorate, 'active')
  returning * into existing;

  return existing;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_create_booking — قلب المنصة.
--
-- العميل يمرّر الخدمة والموعد فقط. الخادم يجلب السعر ونسبة العربون والعمولة
-- وسياسة الإلغاء، ويتحقّق أن مقدّم الخدمة موثّق وأن يومه غير مغلق، ثم ينشئ
-- الحجز ودفعة العربون المعلّقة.
--
-- `p_pay_full` يختار بين دفع العربون أو المبلغ كاملاً، كما تنص الوثيقة.
-- ----------------------------------------------------------------------------
create or replace function public.api_create_booking(
  p_service_id   uuid,
  p_event_date   date,
  p_event_time   time default null,
  p_plan_id      uuid default null,
  p_guests_count integer default 0,
  p_address      text default '',
  p_notes        text default '',
  p_pay_full     boolean default false
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
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if p_event_date < current_date then
    raise exception 'لا يمكن الحجز في تاريخ مضى';
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

  -- التقويم: يوم أغلقه مقدّم الخدمة لا يُحجز
  if exists (
    select 1 from public.provider_availability a
    where a.provider_id = svc.provider_id and a.day = p_event_date and a.is_blocked
  ) then
    raise exception 'مقدّم الخدمة غير متاح في هذا التاريخ';
  end if;

  -- خطة العرس إن مُرّرت يجب أن تكون خطة العميل نفسه
  if p_plan_id is not null and not exists (
    select 1 from public.wedding_plans w where w.id = p_plan_id and w.user_id = me
  ) then
    raise exception 'خطة العرس غير موجودة';
  end if;

  select * into settings from public.app_settings where id = 1;
  commission := coalesce(svc.provider_commission, settings.commission_percent);

  due := case
    when p_pay_full then svc.price
    else round(svc.price * svc.deposit_percent / 100.0, 2)
  end;

  insert into public.bookings (
    reference, user_id, user_name, provider_id, provider_name,
    service_id, service_title, category_id, category_name, plan_id,
    event_date, event_time, governorate, address, guests_count, notes,
    status, total_price, deposit_amount, paid_amount,
    commission_percent, commission_amount, cancellation_rules
  ) values (
    'BK-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    svc.id, svc.title, svc.category_id, svc.category_name, p_plan_id,
    p_event_date, p_event_time, me_row.governorate, p_address, p_guests_count, p_notes,
    'pending_provider', svc.price, round(svc.price * svc.deposit_percent / 100.0, 2), 0,
    commission, 0, svc.rules
  ) returning * into booking;

  -- الدفعة تبدأ معلّقة؛ خطّاف بوابة الدفع هو من يحوّلها إلى «مدفوعة».
  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, platform_share, net_amount, status
  ) values (
    'TRX-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    booking.id, booking.reference,
    case when p_pay_full then 'full' else 'deposit' end,
    case when p_pay_full then 'سداد كامل — ' else 'عربون حجز — ' end || svc.category_name,
    due, round(due * commission / 100.0, 2), due - round(due * commission / 100.0, 2),
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

-- ----------------------------------------------------------------------------
-- api_cancel_booking — إلغاء العميل، والاسترداد بحسب السلّم المنسوخ في الحجز.
-- ----------------------------------------------------------------------------
create or replace function public.api_cancel_booking(
  p_booking_id uuid,
  p_reason     text default ''
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  booking public.bookings;
  refund  numeric(12,2);
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.user_id is distinct from me and not public.can_write() then
    raise exception 'لا تملك صلاحية إلغاء هذا الحجز';
  end if;
  if booking.status in ('completed', 'cancelled', 'rejected') then
    raise exception 'لا يمكن إلغاء حجز في حالته الحالية';
  end if;

  refund := public.refundable_amount(booking.id);

  update public.bookings set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = coalesce(nullif(p_reason, ''), 'ألغى العميل الحجز.'),
    refunded_amount = refund
  where id = booking.id
  returning * into booking;

  -- الاسترداد يُقيَّد كعملية مستقلة ليبقى أثره في الدفتر.
  if refund > 0 then
    insert into public.payments (
      reference, user_id, user_name, provider_id, provider_name,
      booking_id, booking_reference, kind, description,
      amount, platform_share, net_amount, status, refunded_at
    ) values (
      'RFD-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
      booking.id, booking.reference, 'refund',
      'استرداد إلغاء — ' || booking.category_name,
      refund, 0, 0, 'refunded', now()
    );
  end if;

  perform public.notify_provider(
    booking.provider_id, 'booking', 'أُلغي حجز',
    'ألغى العميل الحجز ' || booking.reference || '.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_submit_review — تقييم بعد التنفيذ فقط، ثم تُحدَّث سمعة مقدّم الخدمة.
-- ----------------------------------------------------------------------------
create or replace function public.api_submit_review(
  p_booking_id uuid,
  p_rating     integer,
  p_comment    text default ''
)
returns public.reviews
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  booking public.bookings;
  review  public.reviews;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.user_id is distinct from me then
    raise exception 'لا يمكنك تقييم حجز ليس لك';
  end if;
  -- شرط الوثيقة: التقييم عقب إتمام وتأكيد تنفيذ الحجز فقط
  if booking.status <> 'completed' then
    raise exception 'التقييم متاح بعد تنفيذ الخدمة فقط';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'التقييم يجب أن يكون بين 1 و 5';
  end if;

  insert into public.reviews (booking_id, user_id, user_name, provider_id, rating, comment)
  values (booking.id, me, booking.user_name, booking.provider_id, p_rating, p_comment)
  on conflict (booking_id) do update
    set rating = excluded.rating, comment = excluded.comment, created_at = now()
  returning * into review;

  perform public.recalc_provider_rating(booking.provider_id);

  perform public.notify_provider(
    booking.provider_id, 'review', 'تقييم جديد',
    'قيّم العميل خدمتك بـ ' || p_rating || ' نجوم.',
    jsonb_build_object('booking_id', booking.id)
  );

  return review;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_open_dispute — يفتحه أي من الطرفين على حجز يخصّه.
-- ----------------------------------------------------------------------------
create or replace function public.api_open_dispute(
  p_booking_id  uuid,
  p_subject     text,
  p_description text default '',
  p_category    text default 'other'
)
returns public.disputes
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  as_prov  uuid := public.current_provider();
  booking  public.bookings;
  opener   text;
  dispute  public.disputes;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  if booking.user_id = me then
    opener := 'customer';
  elsif booking.provider_id = as_prov and as_prov is not null then
    opener := 'provider';
  else
    raise exception 'لا تملك صلاحية فتح نزاع على هذا الحجز';
  end if;

  insert into public.disputes (
    reference, booking_id, booking_reference, opened_by,
    user_id, user_name, provider_id, provider_name,
    subject, description, category
  ) values (
    'DSP-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    booking.id, booking.reference, opener,
    booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
    p_subject, p_description, p_category
  ) returning * into dispute;

  insert into public.dispute_messages (dispute_id, author, author_name, body)
  values (dispute.id, opener,
          case when opener = 'customer' then booking.user_name else booking.provider_name end,
          coalesce(nullif(p_description, ''), p_subject));

  return dispute;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_toggle_favourite — إضافة/إزالة خدمة من المفضّلة، وتعيد الحالة الجديدة.
-- ----------------------------------------------------------------------------
create or replace function public.api_toggle_favourite(p_service_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.current_app_user();
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if exists (select 1 from public.favourites where user_id = me and service_id = p_service_id) then
    delete from public.favourites where user_id = me and service_id = p_service_id;
    return false;
  end if;

  insert into public.favourites (user_id, service_id) values (me, p_service_id);
  return true;
end;
$$;

-- ============================================================================
--  دوال مقدّم الخدمة
-- ============================================================================

-- ----------------------------------------------------------------------------
-- api_apply_as_provider — «أريد تقديم خدمة»: ينشئ ملفاً قيد المراجعة.
-- الحساب يبقى مستخدماً عادياً حتى توافق الإدارة، كما تنص الوثيقة.
-- ----------------------------------------------------------------------------
create or replace function public.api_apply_as_provider(
  p_business_name text,
  p_phone         text default '',
  p_bio           text default '',
  p_governorate   text default '',
  p_category_ids  uuid[] default '{}'
)
returns public.service_providers
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  me_row   public.app_users;
  gov_id   uuid;
  provider public.service_providers;
  cat      uuid;
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if exists (select 1 from public.service_providers where user_id = me) then
    raise exception 'لديك طلب أو حساب مقدّم خدمة بالفعل';
  end if;

  select * into me_row from public.app_users where id = me;
  select id into gov_id from public.governorates where name = p_governorate;

  insert into public.service_providers (
    user_id, full_name, business_name, email, phone, bio,
    governorate_id, governorate, coverage_areas, status
  ) values (
    me, me_row.full_name, p_business_name, me_row.email, coalesce(nullif(p_phone,''), me_row.phone),
    p_bio, gov_id, coalesce(nullif(p_governorate,''), me_row.governorate),
    case when p_governorate = '' then '{}' else array[p_governorate] end,
    'pending'
  ) returning * into provider;

  foreach cat in array p_category_ids loop
    insert into public.provider_categories (provider_id, category_id)
    values (provider.id, cat) on conflict do nothing;
  end loop;

  return provider;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_respond_to_booking — قبول الحجز أو رفضه.
--
-- الرفض يستردّ للعميل كل ما دفعه: الخطأ ليس منه.
-- ----------------------------------------------------------------------------
create or replace function public.api_respond_to_booking(
  p_booking_id uuid,
  p_accept     boolean,
  p_reason     text default ''
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  as_prov uuid := public.current_provider();
  booking public.bookings;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  -- is distinct from, لأن as_prov تكون NULL لمن ليس مقدّم خدمة، و`<>` مع NULL
  -- تعطي NULL فيمرّ الفحص ويقبل العميل حجزه بنفسه.
  if booking.provider_id is distinct from as_prov and not public.can_write() then
    raise exception 'لا تملك صلاحية الرد على هذا الحجز';
  end if;
  if booking.status <> 'pending_provider' then
    raise exception 'تم الرد على هذا الحجز مسبقاً';
  end if;

  if p_accept then
    update public.bookings set
      status = 'confirmed',
      confirmed_at = now(),
      commission_amount = round(total_price * commission_percent / 100.0, 2)
    where id = booking.id
    returning * into booking;

    -- الموعد يُغلق في تقويم مقدّم الخدمة فور التأكيد
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (booking.provider_id, booking.event_date, true, 'محجوز — ' || booking.reference)
    on conflict (provider_id, day) do nothing;

    insert into public.invoices (number, booking_id, user_id, provider_id, subtotal, commission, total)
    values (
      'INV-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      booking.id, booking.user_id, booking.provider_id,
      booking.total_price, booking.commission_amount, booking.total_price
    );

    perform public.notify_user(
      booking.user_id, 'booking', 'تم تأكيد حجزك',
      'قبل مقدّم الخدمة حجزك ' || booking.reference || '.',
      jsonb_build_object('booking_id', booking.id)
    );
  else
    update public.bookings set
      status = 'rejected',
      cancelled_at = now(),
      rejection_reason = coalesce(nullif(p_reason, ''), 'اعتذر مقدّم الخدمة.'),
      refunded_amount = paid_amount
    where id = booking.id
    returning * into booking;

    if booking.paid_amount > 0 then
      insert into public.payments (
        reference, user_id, user_name, provider_id, provider_name,
        booking_id, booking_reference, kind, description,
        amount, platform_share, net_amount, status, refunded_at
      ) values (
        'RFD-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
        booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
        booking.id, booking.reference, 'refund',
        'استرداد رفض — ' || booking.category_name,
        booking.paid_amount, 0, 0, 'refunded', now()
      );
    end if;

    perform public.notify_user(
      booking.user_id, 'booking', 'اعتذر مقدّم الخدمة',
      'رُفض الحجز ' || booking.reference || ' وسيُعاد المبلغ المدفوع.',
      jsonb_build_object('booking_id', booking.id)
    );
  end if;

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_complete_booking — تأكيد تنفيذ الخدمة، وبه يُفتح باب التقييم.
-- ----------------------------------------------------------------------------
create or replace function public.api_complete_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  as_prov uuid := public.current_provider();
  booking public.bookings;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.provider_id is distinct from as_prov and not public.can_write() then
    raise exception 'لا تملك صلاحية إنهاء هذا الحجز';
  end if;
  if booking.status <> 'confirmed' then
    raise exception 'لا يمكن إنهاء حجز غير مؤكد';
  end if;

  update public.bookings set status = 'completed', completed_at = now()
  where id = booking.id returning * into booking;

  -- عدّادات المنصة، لا تعديل من مقدّم الخدمة: يُرفع العلم الداخلي ليمرّ الحارس.
  perform set_config('app.internal', 'on', true);
  update public.service_providers
  set completed_bookings = completed_bookings + 1,
      total_earnings = total_earnings + (booking.total_price - booking.commission_amount)
  where id = booking.provider_id;
  perform set_config('app.internal', 'off', true);

  perform public.notify_user(
    booking.user_id, 'review', 'كيف كانت الخدمة؟',
    'شاركنا رأيك في الخدمة التي نُفّذت.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ============================================================================
--  دوال داخلية — لا تُستدعى من التطبيق
-- ============================================================================

create or replace function public.notify_user(
  p_user_id uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, data)
  select p_user_id, p_kind, p_title, p_body, p_data where p_user_id is not null;
$$;

create or replace function public.notify_provider(
  p_provider_id uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language sql security definer set search_path = public as $$
  insert into public.notifications (provider_id, kind, title, body, data)
  select p_provider_id, p_kind, p_title, p_body, p_data where p_provider_id is not null;
$$;

-- متوسط التقييم يُعاد حسابه من التقييمات المنشورة وحدها
create or replace function public.recalc_provider_rating(p_provider_id uuid)
returns void language sql security definer set search_path = public as $$
  select set_config('app.internal', 'on', true);
  update public.service_providers p set
    rating = coalesce((
      select round(avg(r.rating)::numeric, 1) from public.reviews r
      where r.provider_id = p_provider_id and r.status = 'published'
    ), 0),
    reviews_count = (
      select count(*) from public.reviews r
      where r.provider_id = p_provider_id and r.status = 'published'
    )
  where p.id = p_provider_id;
  select set_config('app.internal', 'off', true);
$$;

-- ----------------------------------------------------------------------------
-- api_confirm_payment — يستدعيها خطّاف بوابة الدفع بمفتاح الخدمة، لا التطبيق.
-- تحويل دفعة إلى «مدفوعة» يزيد المدفوع في الحجز بنفس المقدار.
-- ----------------------------------------------------------------------------
create or replace function public.api_confirm_payment(
  p_payment_id  uuid,
  p_gateway_ref text default '',
  p_method      text default 'jawali'
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  pay public.payments;
begin
  select * into pay from public.payments where id = p_payment_id;
  if not found then
    raise exception 'العملية غير موجودة';
  end if;
  if pay.status = 'paid' then
    return pay;  -- إعادة استدعاء الخطّاف مرتين لا تُضاعف المبلغ
  end if;
  if pay.status <> 'pending' then
    raise exception 'لا يمكن تأكيد عملية في حالتها الحالية';
  end if;

  update public.payments
  set status = 'paid', gateway_ref = p_gateway_ref, method = p_method
  where id = pay.id returning * into pay;

  if pay.booking_id is not null then
    update public.bookings
    set paid_amount = paid_amount + pay.amount
    where id = pay.booking_id;
  end if;

  perform public.notify_user(
    pay.user_id, 'payment', 'تم استلام الدفعة',
    'تم تأكيد دفعتك بنجاح.',
    jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
  );

  return pay;
end;
$$;

-- ============================================================================
--  الصلاحيات: الدوال الموجّهة للتطبيقين فقط تُمنح للمستخدمين المسجَّلين.
--  api_confirm_payment ليست منها — تبقى لمفتاح الخدمة وحده.
-- ============================================================================

revoke all on function public.api_confirm_payment(uuid, text, text) from public, anon, authenticated;

grant execute on function
  public.api_register_profile(text, text, text, text),
  public.api_create_booking(uuid, date, time, uuid, integer, text, text, boolean),
  public.api_cancel_booking(uuid, text),
  public.api_submit_review(uuid, integer, text),
  public.api_open_dispute(uuid, text, text, text),
  public.api_toggle_favourite(uuid),
  public.api_apply_as_provider(text, text, text, text, uuid[]),
  public.api_respond_to_booking(uuid, boolean, text),
  public.api_complete_booking(uuid)
to authenticated;

grant select on public.v_services, public.v_providers to anon, authenticated;
grant select on public.v_plan_summary to authenticated;
