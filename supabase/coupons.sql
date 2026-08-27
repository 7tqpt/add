-- ============================================================================
--  الكوبونات: كودُ خصمٍ يكتبه العميل عند الحجز
--
--  شغّله بعد `api.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** لا كودَ خصمٍ في القاعدة كلِّها. و`promotions.sql` شيءٌ
--  آخر تماماً — إعلانٌ يشتريه مقدّمُ الخدمة ليظهر في الرئيسية. فبابُ التسويق
--  للعميل مغلق: لا حملةَ عيدٍ ولا كودَ إطلاق.
--
--  ── ثلاثة قراراتٍ في هذا الملفّ تستحقّ أن تُقرأ قبل الشيفرة ──────────────
--
--  **١) المنصّةُ هي من تدفع الخصم لا مقدّمُ الخدمة.**
--
--  الحملةُ حملةُ المنصّة، فلا يجوز أن تُخصَم من مال صاحب القاعة الذي اتّفق
--  على سعره. ولو خُصمت منه لَخرج من المنصّة أوّلَ حملة.
--
--  والتسويةُ في `settlements.sql` تحسب للمزوّد `paid_amount - commission_amount`
--  — أي **المقبوض ناقص العمولة**. فلو نقص المقبوضُ بالخصم وحده لَنقص نصيبُ
--  المزوّد بمقداره. فالخصم يُطرح من **العمولة** بالقدر نفسه:
--
--      المقبوض  = السعر − الخصم
--      العمولة  = (السعر × النسبة) − الخصم
--      للمزوّد  = المقبوض − العمولة = السعر − (السعر × النسبة)
--
--  وهو نصيبُه لو لم يكن هناك كوبونٌ أصلاً. الخصمُ كلُّه من جيب المنصّة.
--
--  **٢) والخصمُ محدودٌ بالعمولة — لأنّ المنصّة لا تُعطي ما لا تملك.**
--
--  لو كانت العمولة ١٠٪ وأنشأتَ كوبون ٥٠٪، فالمنصّة لا تملك إلّا عشرة تعطيها،
--  والأربعون الباقية مالُ المزوّد لا مالُها. فيُقصّ الخصمُ عند العمولة.
--
--  وهذا لا يقع في الخفاء: `api_check_coupon` تُرجع **المبلغ المطبَّق فعلاً**،
--  فيراه العميل في التطبيق قبل أن يؤكّد، وتراه الإدارةُ في اللوحة. ولو أردتَ
--  خصماً أكبر من عمولتك فارفع العمولة أوّلاً، أو حوّل المال إلى المزوّد
--  خارج المنصّة — والقاعدة لا تعرف حوالةً لم تمرّ بها.
--
--  **٣) ولا أحدَ يقرأ جدول الكوبونات — ولا العميل.**
--
--  لو قُرئ الجدولُ من التطبيق لَجمع أوّلُ فضوليٍّ كلَّ كودٍ في المنصّة
--  واستعملها كلَّها. فلا سياسةَ قراءةٍ إلّا للإدارة، والعميلُ يتحقّق من كودٍ
--  **يعرفه هو** عبر دالّةٍ `security definer` — تُجيب عن كودٍ واحدٍ سُئلت عنه
--  ولا تعدّ له غيره.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- الجدول
-- ----------------------------------------------------------------------------
create table if not exists public.coupons (
  id           uuid primary key default gen_random_uuid(),

  -- الكودُ يُخزَّن بحروفٍ كبيرة ويُقارَن كذلك: من يكتب `eid25` في جواله
  -- يقصد `EID25`، ولا يُحرم من خصمه لأنّ لوحة مفاتيحه لم ترفع الحرف.
  code         text not null unique,
  description  text not null default '',

  kind         text not null check (kind in ('percent', 'fixed')),
  value        numeric(12, 2) not null check (value > 0),

  -- سقفُ النسبة بالريال. صفرٌ يعني بلا سقف — و«١٥٪ بحدّ أقصى ٥٠٠٠» هو ما
  -- يُكتب في الحملات فعلاً، وإلّا صارت النسبةُ على قاعةٍ بمليونٍ مئةَ ألف.
  max_discount numeric(12, 2) not null default 0 check (max_discount >= 0),
  -- أقلُّ إجمالي حجزٍ يقبله الكود.
  min_total    numeric(12, 2) not null default 0 check (min_total >= 0),

  -- قسمٌ بعينه، أو NULL لكلّ الأقسام.
  category_id  uuid references public.service_categories (id) on delete cascade,

  starts_at    timestamptz not null default now(),
  ends_at      timestamptz,

  -- صفرٌ = بلا حدّ. و`max_uses_per_user` مرّةٌ واحدةٌ افتراضاً: كودُ حملةٍ
  -- بلا هذا الحدّ يستنزفه حسابٌ واحد.
  max_uses          integer not null default 0 check (max_uses >= 0),
  max_uses_per_user integer not null default 1 check (max_uses_per_user >= 0),
  used_count        integer not null default 0 check (used_count >= 0),

  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  created_by   uuid references public.app_users (id) on delete set null,

  -- نسبةٌ فوق المئة ليست خصماً بل هديّة.
  constraint coupon_percent_within_100
    check (kind <> 'percent' or value <= 100),
  -- ونافذةٌ تنتهي قبل أن تبدأ لا تُفتح أبداً، فتُمنع عند الإنشاء لا عند أوّل
  -- عميلٍ يشتكي أنّ الكود «غير صحيح».
  constraint coupon_window_ordered
    check (ends_at is null or ends_at > starts_at)
);

create index if not exists coupons_active_idx
  on public.coupons (code) where is_active;

-- ----------------------------------------------------------------------------
-- الاستعمالات
--
-- صفٌّ لكلّ استعمال. وهو ما يُحتسب منه حدُّ المستخدم، وما تُقرأ منه الحملةُ
-- في اللوحة: كم مرّةً استُعمل الكود، وكم كلّف.
-- ----------------------------------------------------------------------------
create table if not exists public.coupon_redemptions (
  id          uuid primary key default gen_random_uuid(),
  coupon_id   uuid not null references public.coupons (id) on delete cascade,
  user_id     uuid not null references public.app_users (id) on delete cascade,
  -- **كوبونٌ واحدٌ للحجز الواحد** — قيدٌ في القاعدة لا شرطٌ في الشيفرة.
  booking_id  uuid not null unique references public.bookings (id) on delete cascade,
  code        text not null default '',
  amount      numeric(12, 2) not null default 0 check (amount >= 0),
  created_at  timestamptz not null default now()
);

create index if not exists coupon_redemptions_coupon_idx
  on public.coupon_redemptions (coupon_id);
create index if not exists coupon_redemptions_user_idx
  on public.coupon_redemptions (user_id, coupon_id);

-- ----------------------------------------------------------------------------
-- عمودان في الحجز
--
-- الكودُ يُنسخ في الحجز نصّاً كما تُنسخ سياسةُ الإلغاء: الكوبون قد يُحذف بعد
-- سنة، والحجزُ يبقى ويجب أن يقول ما جرى فيه.
-- ----------------------------------------------------------------------------
alter table public.bookings
  add column if not exists coupon_code     text not null default '',
  add column if not exists discount_amount numeric(12, 2) not null default 0;

do $$ begin
  alter table public.bookings
    add constraint discount_within_total check (discount_amount <= total_price);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.bookings
    add constraint discount_not_negative check (discount_amount >= 0);
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- RLS — لا قراءةَ إلّا للإدارة
-- ----------------------------------------------------------------------------
alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;

drop policy if exists coupons_admin_read on public.coupons;
create policy coupons_admin_read on public.coupons
  for select to authenticated
  using (public.can_read_area('finance'));

drop policy if exists coupons_admin_write on public.coupons;
create policy coupons_admin_write on public.coupons
  for all to authenticated
  using (public.can_write_area('finance'))
  with check (public.can_write_area('finance'));

-- والعميل يرى **استعمالاته هو** — ليعرف أين ذهب كودُه إن سأل.
drop policy if exists redemptions_own_read on public.coupon_redemptions;
create policy redemptions_own_read on public.coupon_redemptions
  for select to authenticated
  using (user_id = public.current_app_user() or public.can_read_area('finance'));

grant select on public.coupons to authenticated;
grant insert, update, delete on public.coupons to authenticated;
grant select on public.coupon_redemptions to authenticated;

-- ----------------------------------------------------------------------------
-- حسابُ الخصم — قلبُ الملفّ، وموضعُ كلّ قاعدة
--
-- تُستدعى مرّتين: مرّةً استشارةً من `api_check_coupon` قبل الحجز، ومرّةً
-- حُكماً من `api_create_booking` عند الإنشاء. وما يُفحص قبل الضغط يُعاد فحصُه
-- عند الكتابة — فبين الشاشتين دقائقُ تنتهي فيها الحملة أو ينفد العدد.
-- ----------------------------------------------------------------------------
create or replace function public.coupon_discount(
  c              public.coupons,
  p_user_id      uuid,
  p_price        numeric,
  p_category_id  uuid,
  p_commission   numeric
)
returns numeric
language plpgsql stable security definer set search_path = public as $$
declare
  used_by_me integer;
  discount   numeric(12, 2);
begin
  if not c.is_active then
    raise exception 'هذا الكود موقوف';
  end if;
  if now() < c.starts_at then
    raise exception 'لم تبدأ صلاحية هذا الكود بعد';
  end if;
  if c.ends_at is not null and now() > c.ends_at then
    raise exception 'انتهت صلاحية هذا الكود';
  end if;
  if c.max_uses > 0 and c.used_count >= c.max_uses then
    raise exception 'انتهى عدد استعمالات هذا الكود';
  end if;

  if c.max_uses_per_user > 0 then
    select count(*) into used_by_me
      from public.coupon_redemptions r
     where r.coupon_id = c.id and r.user_id = p_user_id;
    if used_by_me >= c.max_uses_per_user then
      raise exception 'استعملتَ هذا الكود من قبل';
    end if;
  end if;

  if c.category_id is not null and c.category_id is distinct from p_category_id then
    raise exception 'هذا الكود لا ينطبق على هذا القسم';
  end if;

  if p_price < c.min_total then
    raise exception 'هذا الكود لحجزٍ من % ريال فأكثر',
      to_char(c.min_total, 'FM999,999,999');
  end if;

  discount := case c.kind
    when 'percent' then round(p_price * c.value / 100.0, 2)
    else c.value
  end;

  -- سقفُ النسبة إن ضُبط.
  if c.kind = 'percent' and c.max_discount > 0 then
    discount := least(discount, c.max_discount);
  end if;

  -- **ولا يتجاوز الخصمُ ما تملكه المنصّة:** لا السعرَ نفسه، ولا عمولتَها منه.
  -- والقصُّ هنا هو القرارُ الثاني في رأس الملفّ — يُقرأ هناك.
  discount := least(discount, p_price, greatest(p_commission, 0));

  if discount <= 0 then
    raise exception 'لا ينطبق هذا الكود على هذا الحجز';
  end if;

  return discount;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_check_coupon — يتحقّق العميل من كودٍ يعرفه قبل أن يحجز
--
-- **`returns table` لا `returns public.coupons`:** الدالّة المُرجِعة لنوعٍ
-- مركَّبٍ تُقرأ من PostgREST بـ `select * from f()`، والمركَّبُ الفارغ يتمدّد
-- هناك إلى **صفٍّ كلُّه NULL** لا إلى «لا صفّ». وقد أسقط هذا شاشةَ الباقات
-- وشاشةَ إكمال الملفّ في هذا المشروع قبل اليوم بـ
-- `type 'Null' is not a subtype of type 'String'`.
-- ----------------------------------------------------------------------------
create or replace function public.api_check_coupon(
  p_code       text,
  p_service_id uuid
)
returns table (code text, description text, discount numeric)
language plpgsql stable security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  c        public.coupons;
  svc      record;
  settings public.app_settings;
  comm     numeric(5, 2);
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into c from public.coupons k
   where k.code = upper(btrim(p_code));
  if not found then
    raise exception 'هذا الكود غير صحيح';
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
end;
$$;

revoke all on function public.api_check_coupon(text, uuid) from public;
grant execute on function public.api_check_coupon(text, uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- api_create_booking — بمعاملٍ زائد
--
-- **`drop` ثم `create` لا `create or replace`:** إضافةُ معاملٍ — ولو بقيمةٍ
-- افتراضية — تُنشئ دالّةً **ثانية** بجانب الأولى لا بديلاً عنها، فيصير
-- النداءُ من التطبيق ملتبساً بين توقيعين. والقديمةُ تُسقَط باسمها وتوقيعها.
-- ----------------------------------------------------------------------------
drop function if exists public.api_create_booking(
  uuid, date, time, uuid, integer, text, text, boolean);

create or replace function public.api_create_booking(
  p_service_id   uuid,
  p_event_date   date,
  p_event_time   time default null,
  p_plan_id      uuid default null,
  p_guests_count integer default 0,
  p_address      text default '',
  p_notes        text default '',
  p_pay_full     boolean default false,
  p_coupon_code  text default ''
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
  comm_base  := round(svc.price * commission / 100.0, 2);

  -- ── الكوبون ───────────────────────────────────────────────────────────────
  -- **`for update` لا قراءةٌ عادية:** عميلان يحجزان في اللحظة نفسها بآخر
  -- استعمالٍ في الكود يقرآن `used_count` نفسه فيمرّان معاً، ويُصرف الكودُ
  -- مرّتين وحدُّه واحد. والقفلُ يجعل الثانيَ ينتظر ثم يقرأ العددَ بعد زيادته.
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
  -- الخصمُ يُطرح ممّا يُدفع الآن، ولا ينزل بالمستحقّ تحت الصفر.
  due := greatest(due - discount, 0);

  insert into public.bookings (
    reference, user_id, user_name, provider_id, provider_name,
    service_id, service_title, category_id, category_name, plan_id,
    event_date, event_time, governorate, address, guests_count, notes,
    status, total_price, deposit_amount, paid_amount,
    commission_percent, commission_amount, cancellation_rules,
    coupon_code, discount_amount
  ) values (
    'BK-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    svc.id, svc.title, svc.category_id, svc.category_name, p_plan_id,
    p_event_date, p_event_time, me_row.governorate, p_address, p_guests_count, p_notes,
    'pending_provider', svc.price, round(svc.price * svc.deposit_percent / 100.0, 2), 0,
    commission, 0, svc.rules,
    coalesce(coupon.code, ''), discount
  ) returning * into booking;

  if discount > 0 then
    insert into public.coupon_redemptions (coupon_id, user_id, booking_id, code, amount)
      values (coupon.id, me, booking.id, coupon.code, discount);
    update public.coupons set used_count = used_count + 1 where id = coupon.id;
  end if;

  -- الدفعة تبدأ معلّقة؛ خطّاف بوابة الدفع هو من يحوّلها إلى «مدفوعة».
  --
  -- **ونصيبُ المنصّة هو ما ينقص بالخصم لا نصيبُ المزوّد** — القرارُ الأوّل في
  -- رأس الملفّ. و`greatest(…, 0)` لأنّ `platform_share` لا يقبل سالباً،
  -- والخصمُ مقصوصٌ عند العمولة فلا يبلغها أصلاً.
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
  uuid, date, time, uuid, integer, text, text, boolean, text) from public;
grant execute on function public.api_create_booking(
  uuid, date, time, uuid, integer, text, text, boolean, text) to authenticated;

-- ----------------------------------------------------------------------------
-- api_respond_to_booking — والعمولةُ عند القبول تعرف الخصم
--
-- تُعاد كتابتها هنا كما هي في `api.sql` إلّا في سطرين، وهما مشروحان في موضعهما.
-- ----------------------------------------------------------------------------
alter table public.invoices
  add column if not exists discount numeric(12, 2) not null default 0
    check (discount >= 0);

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

-- ----------------------------------------------------------------------------
-- الحجزُ الذي لم يقع يردّ الكود
--
-- يحجز العميل بكوده، فيعتذر مقدّمُ الخدمة أو تنقضي المهلة — فيكون الكودُ قد
-- احترق في حجزٍ لم يقع. وهذه تذكرةُ دعمٍ في كل حملة.
--
-- ومُشغِّلٌ لا شرطٌ في دالّة الإلغاء: الحجزُ يُغلق من أربعة مسارات — إلغاءُ
-- العميل، واعتذارُ المزوّد، وانقضاءُ المهلة، وإجراءُ الإدارة — ومن كتب الردَّ
-- في واحدٍ منها نسيه في الثلاثة.
-- ----------------------------------------------------------------------------
create or replace function public.release_coupon_on_close()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  freed public.coupon_redemptions;
begin
  if new.status in ('rejected', 'cancelled', 'expired')
     and old.status not in ('rejected', 'cancelled', 'expired') then
    delete from public.coupon_redemptions r
     where r.booking_id = new.id
     returning * into freed;
    if found then
      update public.coupons
         set used_count = greatest(used_count - 1, 0)
       where id = freed.coupon_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_release_coupon on public.bookings;
create trigger bookings_release_coupon
  after update of status on public.bookings
  for each row execute function public.release_coupon_on_close();

-- ----------------------------------------------------------------------------
-- طريقةُ عرضٍ للوحة: الكوبون وحصادُه في صفٍّ واحد
-- ----------------------------------------------------------------------------
drop view if exists public.v_coupons;

create view public.v_coupons
with (security_invoker = true) as
select
  c.*,
  cat.name as category_name,
  coalesce(r.redemptions, 0)   as redemptions,
  coalesce(r.total_discount, 0) as total_discount,
  -- «سارٍ الآن» يُحسب هنا مرّةً بدل أن يُعاد في اللوحة وفي التطبيق وفي تقرير،
  -- فتفترق الثلاثةُ في تعريف «سارٍ».
  (c.is_active
    and now() >= c.starts_at
    and (c.ends_at is null or now() <= c.ends_at)
    and (c.max_uses = 0 or c.used_count < c.max_uses)) as is_live
from public.coupons c
left join public.service_categories cat on cat.id = c.category_id
left join lateral (
  select count(*)::integer as redemptions, sum(x.amount) as total_discount
    from public.coupon_redemptions x
   where x.coupon_id = c.id
) r on true;

grant select on public.v_coupons to authenticated;

commit;
