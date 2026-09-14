-- ============================================================================
--  مراجعةُ الإدارة لتنفيذ الحجز
--
--  طلب صاحبُ المنصّة: «وترسل للإدارة لمراجعات تنفيذ الحجز عشان يطلع له تم
--  تنفيذ الحجز. قبل تنفيذ يطلع له مراجعات الإدارة».
--
--  ── ما كان وما صار ─────────────────────────────────────────────────────────
--
--  كان: يضغط المزوّد «تأكيد التنفيذ» فتُنادى `api_complete_booking` فيصير
--  الحجزُ `completed` **في اللحظة**، وتزيد `total_earnings` و
--  `completed_bookings`، ويُفتح للعميل بابُ التقييم.
--
--  وصار: يضغط المزوّد فيُختم `completion_requested_at` **ولا يتغيّر شيءٌ
--  آخر**. ثمّ يعتمد المسؤولُ من اللوحة فيقع ما كان يقع.
--
--  ── والحرزُ هو أنّ المزوّد لم يعد يملك الإتمام ─────────────────────────────
--
--  **وهذا لبُّ الطلب، وبدونه كلُّ ما سبق زينة.** `api_complete_booking`
--  كانت تقبل `provider_id = current_provider()` — فمن فكّ ملفَّ APK ونادى
--  الدالّةَ مباشرةً أتمّ حجزَه وزاد مستحقّاتِه بلا مراجعة. فأُغلقت هنا على
--  `can_write_area('bookings')` وحدَها.
--
--  ── ولا حالةً جديدةً في `status` ───────────────────────────────────────────
--
--  البديلُ المعتاد أن تُزاد قيمةٌ سابعةٌ إلى `bookings.status`. وهي تمسّ
--  كلَّ قيدٍ وكلَّ شاشةٍ وكلَّ مُطابَقةٍ في التطبيقين واللوحة — وتُري العميلَ
--  حالةً لا تعنيه. فالطلبُ **ختمُ وقت**: الحجزُ يبقى `confirmed` عند الجميع،
--  والمزوّدُ وحدَه يرى «قيد مراجعة الإدارة».
--
--  ── وثمنٌ قيل لصاحب المنصّة قبل أن يُقرّ ───────────────────────────────────
--
--  مستحقّاتُ المزوّد تقف حتى يعتمد المسؤول، **وبابُ التقييم عند العميل يقف
--  معها**. فإن غاب المسؤولُ أسبوعاً وقف المزوّدون كلُّهم.
--
--  ── ولا إشعارَ للمسؤولين ──────────────────────────────────────────────────
--
--  `notifications` صندوقان: عميلٌ أو مزوّد (`notification_has_one_owner`)،
--  ولا صندوقَ لمسؤول. فالطابورُ يُرى في اللوحة بمرشِّح «قيد مراجعة التنفيذ»
--  — وهو ما اختاره: **(ب) مرشِّحٌ داخل صفحة «الحجوزات»**.
--
--  يُنفَّذ بعد `api.sql` و`roles.sql`.
-- ============================================================================

alter table public.bookings
  add column if not exists completion_requested_at timestamptz,
  add column if not exists completion_rejected_at  timestamptz,
  add column if not exists completion_reject_reason text not null default '';

-- طابورُ المراجعة يُقرأ بهذا الفهرس: حجوزاتٌ مؤكَّدةٌ عليها طلبُ اعتماد.
create index if not exists bookings_completion_review_idx
  on public.bookings (completion_requested_at)
  where completion_requested_at is not null;

comment on column public.bookings.completion_requested_at is
  'متى طلب المزوّد اعتمادَ التنفيذ. ليس حالةً في status: الحجز يبقى confirmed '
  'حتى تعتمد الإدارة.';

-- ----------------------------------------------------------------------------
-- api_request_completion — المزوّد يطلب اعتمادَ التنفيذ
-- ----------------------------------------------------------------------------
create or replace function public.api_request_completion(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_provider();
  booking public.bookings;
begin
  if me is null then
    raise exception 'لا ملفَّ مزوّدٍ لهذا الحساب.' using errcode = '42501';
  end if;

  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود.' using errcode = 'P0002';
  end if;

  if booking.provider_id is distinct from me then
    raise exception 'الحجز ليس لك.' using errcode = '42501';
  end if;

  if booking.status <> 'confirmed' then
    raise exception 'لا يُطلب اعتمادُ تنفيذ حجزٍ غيرِ مؤكَّد.' using errcode = '22023';
  end if;

  -- **والطلبُ الثاني لا يُلغي الأوّل ولا يقفز به إلى رأس الطابور.** من ضغط
  -- مرّتين لا يُنتظر مرّتين، ومن ضغط بعد رفضٍ يُعاد طلبُه بتاريخٍ جديد.
  if booking.completion_requested_at is not null then
    return booking;
  end if;

  update public.bookings
     set completion_requested_at  = now(),
         completion_rejected_at   = null,
         completion_reject_reason = ''
   where id = booking.id
  returning * into booking;

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_complete_booking — الإتمامُ نفسُه، وصار للإدارة وحدَها
-- ----------------------------------------------------------------------------
--
-- **وهذه هي التي أُغلقت.** كان فيها `booking.provider_id is distinct from
-- as_prov and not public.can_write()` — أي أنّ صاحبَ الحجز يُتمّه. والحارسُ
-- في الشاشة لا يحرس: الدالّةُ تُنادى من APK مفكوك.
create or replace function public.api_complete_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  booking public.bookings;
begin
  if not public.can_write_area('bookings') then
    raise exception 'اعتمادُ التنفيذ للإدارة وحدَها.' using errcode = '42501';
  end if;

  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود.' using errcode = 'P0002';
  end if;
  if booking.status <> 'confirmed' then
    raise exception 'لا يمكن إنهاء حجز غير مؤكد.' using errcode = '22023';
  end if;

  update public.bookings
     set status                  = 'completed',
         completed_at            = now(),
         completion_requested_at = null
   where id = booking.id
  returning * into booking;

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

  -- **والمزوّدُ يُخبَر أنّ مالَه احتُسب.** بلا هذا ينتظر بلا أن يعلم متى
  -- انتهى انتظارُه، فيفتح التطبيقَ كلَّ يومٍ يسأل.
  perform public.notify_provider(
    booking.provider_id, 'booking', 'اعتُمد تنفيذ الحجز',
    'اعتمدت الإدارةُ تنفيذَ الحجز، وأُضيف إلى مستحقّاتك.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_reject_completion — الإدارةُ تردّ الطلبَ بسببٍ يقرؤه المزوّد
-- ----------------------------------------------------------------------------
--
-- **وبسببٍ لا بصمت.** من رُدّ طلبُه بلا كلمةٍ يُعيده كما هو، فيدور الطابورُ
-- على نفسه.
create or replace function public.api_reject_completion(
  p_booking_id uuid, p_reason text
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  booking public.bookings;
  reason  text := btrim(coalesce(p_reason, ''));
begin
  if not public.can_write_area('bookings') then
    raise exception 'مراجعةُ التنفيذ للإدارة وحدَها.' using errcode = '42501';
  end if;
  if reason = '' then
    raise exception 'اكتب سببَ الردّ.' using errcode = '22023';
  end if;

  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود.' using errcode = 'P0002';
  end if;
  if booking.completion_requested_at is null then
    raise exception 'لا طلبَ اعتمادٍ على هذا الحجز.' using errcode = '22023';
  end if;

  update public.bookings
     set completion_requested_at  = null,
         completion_rejected_at   = now(),
         completion_reject_reason = reason
   where id = booking.id
  returning * into booking;

  perform public.notify_provider(
    booking.provider_id, 'booking', 'رُدَّ طلبُ اعتماد التنفيذ',
    reason,
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

revoke all on function public.api_request_completion(uuid) from public;
revoke all on function public.api_reject_completion(uuid, text) from public;
grant execute on function public.api_request_completion(uuid) to authenticated;
grant execute on function public.api_reject_completion(uuid, text) to authenticated;

comment on function public.api_request_completion(uuid) is
  'المزوّد يطلب اعتمادَ تنفيذ حجزه. لا يُتمّه — الإتمام للإدارة.';
comment on function public.api_reject_completion(uuid, text) is
  'الإدارة تردّ طلبَ الاعتماد بسببٍ يصل المزوّد إشعاراً.';

notify pgrst, 'reload schema';
