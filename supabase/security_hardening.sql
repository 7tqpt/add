-- إصلاحات المراجعة الأمنية للقواعد القائمة — معاملة واحدة، بلا حذف بيانات.
-- المصدر مركّب من الملفات الأصلية بواسطة tool/security_sql.mjs.
-- شغّل هذا الملف أخيراً بعد ملفات الميزات المذكورة في SECURITY_DEPLOYMENT.md.
begin;

do $$
begin
  if to_regclass('public.admin_areas') is null
     or to_regclass('public.support_tickets') is null
     or to_regclass('public.coupons') is null
     or to_regclass('public.plan_tasks') is null
     or to_regclass('public.service_media') is null
     or to_regclass('public.phone_otp_sends') is null
     or (to_regprocedure('public.api_update_profile(text,text,uuid,text)') is null
         and to_regprocedure('public.api_update_profile(text,text,uuid,text,text)') is null) then
    raise exception 'تحتاج ملفات roles/support/profile/coupons/plan_tasks/service_media/phone_verify قبل هذا الترحيل';
  end if;
  if exists (select 1 from public.bookings where status = 'confirmed' and provider_id is not null
              group by provider_id, event_date having count(*) > 1) then
    raise exception 'توجد حجوزات مؤكدة متعارضة؛ راجع فحص المواعيد في SECURITY_DEPLOYMENT.md قبل الترحيل';
  end if;
end;
$$;

alter table public.app_users add column if not exists phone_verified_at timestamptz;
alter table public.app_settings add column if not exists require_phone_verification boolean not null default false;
drop policy if exists users_self_update on public.app_users;
drop policy if exists users_self_insert on public.app_users;
drop policy if exists availability_owner_write on public.provider_availability;
create unique index if not exists bookings_confirmed_provider_day_key
  on public.bookings (provider_id, event_date)
  where status = 'confirmed' and provider_id is not null;


-- Source: schema.sql
create or replace function public.current_app_user()
returns uuid language sql stable security definer set search_path = public as $$
  select u.id from public.app_users u
   where u.auth_user_id = auth.uid()
     and (not coalesce((select s.require_phone_verification
                         from public.app_settings s where s.id = 1), false)
          or u.phone_verified_at is not null);
$$;

-- Source: policies.sql
create or replace function public.guard_provider_self_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- المسؤول، أو دالة API داخلية رفعت العلم أدناه (تحديث العدّادات والتقييم بعد
  -- إتمام حجز). العلم محلّي المعاملة، فلا يتسرّب إلى طلب آخر.
  if public.can_write_area('directory')
     or coalesce(current_setting('app.internal', true), '') = 'on' then
    return new;
  end if;

  if new.status is distinct from old.status
     or new.verified_at is distinct from old.verified_at
     or new.is_featured is distinct from old.is_featured
     or new.commission_percent is distinct from old.commission_percent
     or new.rating is distinct from old.rating
     or new.reviews_count is distinct from old.reviews_count
     or new.completed_bookings is distinct from old.completed_bookings
     or new.total_earnings is distinct from old.total_earnings then
    raise exception 'هذه الحقول تُعدَّل من إدارة المنصة فقط';
  end if;

  return new;
end;
$$;

-- Source: api.sql
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
  if booking.user_id is distinct from me and not public.can_write_area('bookings') then
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

-- Source: coupons.sql
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
  if booking.provider_id is distinct from as_prov and not public.can_write_area('bookings') then
    raise exception 'لا تملك صلاحية الرد على هذا الحجز';
  end if;
  if booking.status <> 'pending_provider' then
    raise exception 'تم الرد على هذا الحجز مسبقاً';
  end if;

  if p_accept then
    if exists (select 1 from public.bookings b
                where b.provider_id = booking.provider_id
                  and b.event_date = booking.event_date
                  and b.status = 'confirmed' and b.id <> booking.id) then
      raise exception 'هذا اليوم محجوز بالفعل لدى مقدّم الخدمة';
    end if;
    update public.bookings set
      status = 'confirmed',
      confirmed_at = now(),
      -- **الخصمُ يُطرح من العمولة هنا أيضاً.**
      --
      -- وهذا هو الموضعُ الذي كاد يُنسى: صفُّ الدفعة كان صحيحاً، ولكنّ
      -- `settlements.sql` لا يقرؤه — بل يقرأ `bookings.paid_amount` ناقص
      -- `bookings.commission_amount`. فلو بقيت العمولةُ هنا كاملةً بينما نقص
      -- المقبوضُ بالخصم، لَخرج الفرقُ من جيب المزوّد في يوم التسوية، بعد
      -- أسابيعَ من الحجز، بلا سطرٍ في أيّ شاشةٍ يقول لماذا.
      --
      -- كشفه اختبارٌ يحجز حجزين متطابقين — بكوبونٍ وبدونه — ويقارن مستحقَّ
      -- المزوّد فيهما.
      commission_amount = greatest(
        round(total_price * commission_percent / 100.0, 2) - discount_amount, 0)
    where id = booking.id
    returning * into booking;

    -- الموعد يُغلق في تقويم مقدّم الخدمة فور التأكيد
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (booking.provider_id, booking.event_date, true, 'محجوز — ' || booking.reference)
    on conflict (provider_id, day) do nothing;

    insert into public.invoices (number, booking_id, user_id, provider_id,
                                subtotal, discount, commission, total)
    values (
      'INV-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      booking.id, booking.user_id, booking.provider_id,
      booking.total_price, booking.discount_amount, booking.commission_amount,
      booking.total_price - booking.discount_amount
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

-- Source: payments_app.sql
create or replace function public.api_admin_confirm_payment(
  p_payment_id  uuid,
  p_gateway_ref text default '',
  p_method      text default null
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  pay public.payments;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية تأكيد المدفوعات';
  end if;

  select * into pay from public.payments where id = p_payment_id;
  if not found then
    raise exception 'العملية غير موجودة';
  end if;

  pay := public.api_confirm_payment(
    p_payment_id,
    coalesce(nullif(btrim(p_gateway_ref), ''), pay.gateway_ref),
    coalesce(p_method, pay.method)
  );

  -- ومقدّمُ الخدمة يُخبَر: وصولُ العربون هو ما يجعله يحجز الموعد فعلاً.
  if pay.provider_id is not null then
    perform public.notify_provider(
      pay.provider_id, 'payment', 'وصلت دفعة',
      'استلمت المنصّة دفعةً على الحجز ' || pay.booking_reference || '.',
      jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
    );
  end if;

  return pay;
end;
$$;

-- Source: payments_app.sql
create or replace function public.api_admin_reject_payment(
  p_payment_id uuid,
  p_reason     text default ''
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  pay public.payments;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية ردّ المدفوعات';
  end if;

  update public.payments
     set status = 'failed',
         description = case when btrim(coalesce(p_reason, '')) = '' then description
                            else description || ' — ' || btrim(p_reason) end
   where id = p_payment_id and status = 'pending'
  returning * into pay;

  if not found then
    raise exception 'لا توجد عمليةٌ معلّقة بهذا الرقم';
  end if;

  perform public.notify_user(
    pay.user_id, 'payment', 'لم نجد حوالتك',
    case when btrim(coalesce(p_reason, '')) = ''
         then 'راجعنا حساباتنا ولم نجد الحوالة. تحقّق من الرقم وأعد الإبلاغ.'
         else btrim(p_reason) end,
    jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
  );

  return pay;
end;
$$;

-- Source: payments_app.sql
create or replace function public.api_admin_refund_payment(
  p_payment_id uuid,
  p_reason     text default ''
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pay      public.payments;
  bk       public.bookings;
  settled  text := 'none';   -- none | pending | paid
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية ردّ المبالغ';
  end if;

  -- **والشرطُ `status = 'paid'` هو ما يمنع ردّين.** مسؤولان يضغطان معاً:
  -- الثاني لا يجد صفّاً فيقف، ولا يُخصم المبلغُ مرّتين من الحجز.
  update public.payments
     set status = 'refunded',
         refunded_at = now()
   where id = p_payment_id and status = 'paid'
  returning * into pay;

  if not found then
    raise exception 'لا توجد دفعةٌ ناجحةٌ بهذا الرقم — قد تكون رُدّت من قبل';
  end if;

  if pay.booking_id is not null then
    -- `least` تحرس قيد `refund_within_paid`: مجموعُ المردود لا يتجاوز
    -- المقبوض. وتجاوزُه يُسقط المعاملةَ بقيدٍ لا يفهمه المسؤول.
    update public.bookings
       set refunded_amount = least(refunded_amount + pay.amount, paid_amount)
     where id = pay.booking_id
    returning * into bk;

    select case when s.status = 'paid' then 'paid' else 'pending' end
      into settled
      from public.settlement_items i
      join public.settlements s on s.id = i.settlement_id
     where i.booking_id = pay.booking_id
     order by case when s.status = 'paid' then 0 else 1 end
     limit 1;

    settled := coalesce(settled, 'none');
  end if;

  perform public.notify_user(
    pay.user_id, 'payment', 'رُدَّ مبلغُك',
    'رُدَّ مبلغُ ' || trim(to_char(pay.amount, 'FM999999999')) || ' ريال عن '
      || coalesce(nullif(pay.booking_reference, ''), 'حجزك')
      || case when btrim(coalesce(p_reason, '')) = '' then '.'
              else ' — ' || btrim(p_reason) end,
    jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
  );

  return jsonb_build_object(
    'payment_id',      pay.id,
    'amount',          pay.amount,
    'booking_id',      pay.booking_id,
    'refunded_amount', coalesce(bk.refunded_amount, 0),
    'settlement',      settled
  );
end;
$$;

-- Source: payments_app.sql
create or replace function public.api_refund_outlook(p_payment_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pay     public.payments;
  settled text;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية ردّ المبالغ';
  end if;

  select * into pay from public.payments where id = p_payment_id;
  if not found then raise exception 'العملية غير موجودة'; end if;

  select case when s.status = 'paid' then 'paid' else 'pending' end
    into settled
    from public.settlement_items i
    join public.settlements s on s.id = i.settlement_id
   where i.booking_id = pay.booking_id
   order by case when s.status = 'paid' then 0 else 1 end
   limit 1;

  return jsonb_build_object(
    'refundable', pay.status = 'paid',
    'amount',     pay.amount,
    'settlement', coalesce(settled, 'none')
  );
end;
$$;

-- Source: support.sql
create or replace function public.admin_reply_ticket(
  p_ticket_id  uuid,
  p_body       text,
  p_internal   boolean default false,
  p_new_status text default null
)
returns public.support_messages
language plpgsql security definer set search_path = public as $$
declare
  ticket  public.support_tickets;
  message public.support_messages;
  actor   text := coalesce(nullif(public.auth_email(), ''), 'الإدارة');
begin
  if not public.can_write_area('support') then
    raise exception 'لا تملك صلاحية الرد';
  end if;
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'الرسالة فارغة';
  end if;

  select * into ticket from public.support_tickets where id = p_ticket_id;
  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  insert into public.support_messages (ticket_id, author, author_name, body, is_internal)
  values (ticket.id, 'admin', actor, btrim(p_body), coalesce(p_internal, false))
  returning * into message;

  if coalesce(p_internal, false) then
    return message;
  end if;

  update public.support_tickets
     set last_message_at   = now(),
         first_response_at = coalesce(first_response_at, now()),
         status = coalesce(nullif(p_new_status, ''), 'waiting_customer'),
         resolved_at = case
           when coalesce(nullif(p_new_status, ''), 'waiting_customer')
                in ('resolved', 'closed') then coalesce(resolved_at, now())
           else null
         end
   where id = ticket.id;

  insert into public.notifications (user_id, provider_id, kind, title, body, data)
  values (
    ticket.user_id, ticket.provider_id, 'message',
    'ردّ من خدمة العملاء',
    left(btrim(p_body), 140),
    jsonb_build_object('ticket_id', ticket.id, 'reference', ticket.reference)
  );

  return message;
end;
$$;

-- Source: availability.sql
create or replace function public.api_set_availability(
  p_day date, p_blocked boolean, p_note text default '')
returns setof public.provider_availability
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

  -- الحجز هو مصدر الحقيقة؛ ملاحظة التقويم قد تكون عذراً سابقاً للحجز.
  if not p_blocked and exists (
    select 1 from public.bookings b
     where b.provider_id = me and b.event_date = p_day and b.status = 'confirmed'
  ) then
    raise exception 'هذا اليوم محجوز — ألغِ الحجز أولاً';
  end if;

  select note into held from public.provider_availability
   where provider_id = me and day = p_day;

  if held is not null and held like 'محجوز — %' then
    if p_blocked then
      -- مغلقٌ أصلاً بحجز؛ الطلب لا يغيّر شيئاً فيُعاد الصفّ كما هو.
      select * into row from public.provider_availability
       where provider_id = me and day = p_day;
      return next row;
      return;
    end if;
    raise exception 'هذا اليوم محجوز (%) — ألغِ الحجز أوّلاً', held;
  end if;

  if p_blocked then
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (me, p_day, true, coalesce(nullif(trim(p_note), ''), 'غير متاح'))
    on conflict (provider_id, day) do update
      set is_blocked = true, note = excluded.note
    returning * into row;
    return next row;
    return;
  end if;

  delete from public.provider_availability
   where provider_id = me and day = p_day
  returning * into row;

  -- **صفٌّ من الأصفار ليس `null`.**
  --
  -- حذفٌ لم يطابق شيئاً يترك `row` بحقولٍ كلُّها فارغة، و`return row` عليها
  -- يُخرج كائناً `{"id": null, "day": null, …}` لا `null`. فيقرأ التطبيق
  -- `day` ويحوّله نصّاً فيسقط بـ«type 'Null' is not a subtype of type
  -- 'String'» — رسالةٌ إنجليزيةٌ في وجه صاحب القاعة مكان تقويمه.
  --
  -- ويقع هذا في أبسط حال: ضغطتان متتاليتان على «افتحه»، أو يومٌ حرّره
  -- إلغاءُ حجزٍ بين لحظة فتح الشاشة ولحظة الضغط.
  --
  -- **و`return null` لا يُصلحه — وهذا ما ظننتُه أوّل مرّة وكان خطأً.**
  -- التمدّد يقع في `select * from f()` الذي يُنفّذه PostgREST، لا في
  -- الدالّة: فـ`NULL` من نوعٍ مركّب يصير هناك صفّاً من الأصفار على كلّ حال.
  -- والذي يُصلحه `setof`: صفرُ صفوفٍ يصل التطبيقَ `[]`. وكلاهما مقيسٌ على
  -- Postgres حقيقيّ.
  if row.id is null then
    return;
  end if;
  return next row;
end $$;

-- Source: phone_verify.sql
create or replace function public.otp_claim_send(
  p_auth_user uuid,
  p_phone     text
)
returns table (allowed boolean, reason text, wait_seconds integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user     uuid;
  v_verified timestamptz;
  v_last     timestamptz;
  v_hour     integer;
  v_day      integer;
begin
  select id, phone_verified_at into v_user, v_verified
    from public.app_users
   where auth_user_id = p_auth_user
   for update;

  if v_user is null then
    return query select false, 'no_profile', 0;
    return;
  end if;

  -- **ومن أكّد لا يُرسَل إليه ثانيةً.** «مرّةً واحدة» قرارُ صاحب المنصّة،
  -- ورسالةٌ بعدها مالٌ يُنفَق بلا سبب.
  if v_verified is not null then
    return query select false, 'already_verified', 0;
    return;
  end if;

  if coalesce(trim(p_phone), '') = '' then
    return query select false, 'no_phone', 0;
    return;
  end if;

  select max(created_at) into v_last
    from public.phone_otp_sends where user_id = v_user;

  if v_last is not null and v_last > now() - interval '60 seconds' then
    return query
      select false,
             'cooldown',
             ceil(extract(epoch from (v_last + interval '60 seconds' - now())))::integer;
    return;
  end if;

  select count(*) into v_hour
    from public.phone_otp_sends
   where user_id = v_user and created_at > now() - interval '1 hour';

  if v_hour >= 3 then
    return query select false, 'hour_limit', 0;
    return;
  end if;

  select count(*) into v_day
    from public.phone_otp_sends
   where user_id = v_user and created_at > now() - interval '24 hours';

  if v_day >= 10 then
    return query select false, 'day_limit', 0;
    return;
  end if;

  insert into public.phone_otp_sends (user_id, phone) values (v_user, p_phone);
  return query select true, 'ok', 0;
end;
$$;

-- Source: policies.sql
drop policy if exists devices_owner on public.user_devices;
create policy devices_owner on public.user_devices
  for all to authenticated
  using (user_id = public.current_app_user() or public.can_write_area('directory'))
  with check (user_id = public.current_app_user() or public.can_write_area('directory'));

-- Source: policies.sql
drop policy if exists devices_admin_read on public.user_devices;
create policy devices_admin_read on public.user_devices
  for select to authenticated using (public.is_admin());

-- Source: policies.sql
drop policy if exists provider_categories_owner on public.provider_categories;
create policy provider_categories_owner on public.provider_categories
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write_area('catalog'))
  with check (provider_id = public.current_provider() or public.can_write_area('catalog'));

-- Source: policies.sql
drop policy if exists services_owner_write on public.provider_services;
create policy services_owner_write on public.provider_services
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write_area('catalog'))
  with check (provider_id = public.current_provider() or public.can_write_area('catalog'));

-- Source: policies.sql
drop policy if exists plans_owner on public.wedding_plans;
create policy plans_owner on public.wedding_plans
  for all to authenticated
  using (user_id = public.current_app_user() or public.can_write_area('bookings'))
  with check (user_id = public.current_app_user() or public.can_write_area('bookings'));

-- Source: policies.sql
drop policy if exists plans_admin_read on public.wedding_plans;
create policy plans_admin_read on public.wedding_plans
  for select to authenticated using (public.is_admin());

-- Source: policies.sql
drop policy if exists favourites_owner on public.favourites;
create policy favourites_owner on public.favourites
  for all to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

-- Source: policies.sql
drop policy if exists dispute_messages_write on public.dispute_messages;
create policy dispute_messages_write on public.dispute_messages
  for insert to authenticated
  with check (
    public.can_write_area('trust')
    or exists (
      select 1 from public.disputes d
      where d.id = dispute_id
        and ((d.user_id = public.current_app_user() and author = 'customer')
             or (d.provider_id = public.current_provider() and author = 'provider'))
    )
  );

-- Source: roles.sql
drop policy if exists push_admin_only on public.push_notifications;
create policy push_admin_only on public.push_notifications
  for all to authenticated
  using (public.can_write_area('ops')) with check (public.can_write_area('ops'));

-- Source: roles.sql
drop policy if exists push_admin_read on public.push_notifications;
create policy push_admin_read on public.push_notifications
  for select to authenticated using (public.can_read_area('ops'));

-- Source: roles.sql
drop policy if exists metrics_admin_only on public.daily_metrics;
create policy metrics_admin_only on public.daily_metrics
  for all to authenticated
  using (public.can_write_area('ops')) with check (public.can_write_area('ops'));

-- Source: roles.sql
drop policy if exists metrics_admin_read on public.daily_metrics;
create policy metrics_admin_read on public.daily_metrics
  for select to authenticated using (public.is_admin());

-- Source: plan_tasks.sql
drop policy if exists plan_tasks_owner on public.plan_tasks;
create policy plan_tasks_owner on public.plan_tasks
  for all to authenticated
  using (
    exists (
      select 1 from public.wedding_plans w
       where w.id = plan_tasks.plan_id and w.user_id = public.current_app_user()
    )
    or public.can_write_area('bookings')
  )
  with check (
    exists (
      select 1 from public.wedding_plans w
       where w.id = plan_tasks.plan_id and w.user_id = public.current_app_user()
    )
    or public.can_write_area('bookings')
  );

-- Source: plan_tasks.sql
drop policy if exists plan_tasks_admin_read on public.plan_tasks;
create policy plan_tasks_admin_read on public.plan_tasks
  for select to authenticated using (public.is_admin());

-- Source: service_media.sql
drop policy if exists media_owner_write on public.service_media;
create policy media_owner_write on public.service_media
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write_area('catalog'))
  with check (provider_id = public.current_provider() or public.can_write_area('catalog'));

-- Source: service_media.sql
drop policy if exists "provider or admin deletes media" on storage.objects;
create policy "provider or admin deletes media" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'service-media'
    and (
      (storage.foldername(name))[1] = public.current_provider()::text
      or public.can_write_area('catalog')
    )
  );

-- Source: chat_media.sql
drop policy if exists "chat media admin deletes" on storage.objects;
create policy "chat media admin deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'chat-media' and public.can_write_area('trust'));

-- سجل العمليات من تغييرات القاعدة الفعلية. شغّل بعد roles.sql.
-- security_hardening.sql يحتوي نسخة من هذا الملف للقواعد القائمة.

-- تبقى نداءات recordAudit القديمة متوافقة: تُهمل الصفوف القادمة مباشرة من
-- المتصفح، ويكتب مشغّل الجدول الحدث الحقيقي في المعاملة نفسها.
-- SECURITY INVOKER مقصودة: current_user يميّز نداء API المباشر عن الدالة
-- الموثوقة التي تعمل بصلاحية مالكها. لا يقبل العميل اختيار كاتب السجل.
create or replace function public.audit_accept_server_entry()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    return null;
  end if;
  if auth.uid() is not null then
    new.actor_email := coalesce((select u.email from auth.users u where u.id = auth.uid()), '');
    new.created_at := clock_timestamp();
    new.details := coalesce(new.details, '{}'::jsonb)
      || jsonb_build_object('source', 'database', 'actor_user_id', auth.uid());
  end if;
  return new;
end;
$$;

drop trigger if exists audit_accept_server_entry on public.audit_log;
create trigger audit_accept_server_entry before insert on public.audit_log
  for each row execute function public.audit_accept_server_entry();

create or replace function public.audit_admin_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  row_data jsonb;
  previous jsonb;
  changed jsonb;
  entity_name text := tg_argv[0];
begin
  row_data := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  previous := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  if actor is null then return null; end if;
  if not public.is_admin()
     and not (tg_table_name = 'admins' and tg_op = 'DELETE'
              and row_data ->> 'user_id' = actor::text) then
    return null;
  end if;
  if tg_op = 'UPDATE' and row_data = previous then return null; end if;

  -- أسماء الحقول وحدها؛ لا ننسخ رسائل الناس أو أرقامهم أو المستندات إلى السجل.
  select coalesce(jsonb_agg(k order by k), '[]'::jsonb) into changed
    from jsonb_object_keys(row_data) as fields(k)
   where tg_op <> 'UPDATE' or row_data -> k is distinct from previous -> k;

  insert into public.audit_log
    (actor_email, action, entity, entity_id, entity_label, details)
  values (
    coalesce((select u.email from auth.users u where u.id = actor), ''),
    case tg_op when 'INSERT' then 'إضافة سجل'
               when 'UPDATE' then 'تعديل سجل' else 'حذف سجل' end,
    entity_name,
    coalesce(row_data ->> 'id', row_data ->> 'user_id', row_data ->> 'role', ''),
    coalesce(row_data ->> 'reference', row_data ->> 'business_name',
             row_data ->> 'full_name', row_data ->> 'title', row_data ->> 'name',
             row_data ->> 'id', tg_table_name),
    jsonb_build_object('source', 'database', 'table', tg_table_name,
                       'operation', tg_op, 'changed_fields', changed)
  );
  return null;
end;
$$;

revoke all on function public.audit_accept_server_entry() from public, anon, authenticated;
revoke all on function public.audit_admin_change() from public, anon, authenticated;

do $$
declare target record;
begin
  for target in select * from (values
    ('app_users', 'user'), ('service_providers', 'provider'),
    ('provider_documents', 'provider'), ('provider_categories', 'provider'),
    ('provider_services', 'service'), ('service_media', 'service'),
    ('bookings', 'booking'), ('wedding_plans', 'plan'), ('plan_tasks', 'plan'),
    ('payments', 'payment'), ('invoices', 'payment'),
    ('settlements', 'settlement'), ('settlement_items', 'settlement'),
    ('provider_subscriptions', 'subscription'), ('subscription_plans', 'subscription'),
    ('promotions', 'promotion'), ('coupons', 'coupon'),
    ('reviews', 'review'), ('disputes', 'dispute'), ('dispute_messages', 'dispute'),
    ('support_tickets', 'support'), ('support_messages', 'support'),
    ('push_notifications', 'notification'), ('app_versions', 'version'),
    ('app_settings', 'settings'), ('service_categories', 'category'),
    ('governorates', 'settings'), ('cancellation_policies', 'policy'),
    ('admins', 'admin'), ('admin_invitations', 'admin'), ('admin_areas', 'admin')
  ) as targets(table_name, entity)
  loop
    if to_regclass('public.' || target.table_name) is not null then
      execute format('drop trigger if exists audit_admin_change on public.%I', target.table_name);
      execute format('create trigger audit_admin_change after insert or update or delete on public.%I
        for each row execute function public.audit_admin_change(%L)', target.table_name, target.entity);
    end if;
  end loop;
end;
$$;



revoke all on function public.seed_plan_tasks(uuid) from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
