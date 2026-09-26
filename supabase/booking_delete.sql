-- ============================================================================
--  حذفُ الحجز — محوٌ نهائيٌّ من القاعدة، بيد صاحبه وبشروط
-- ============================================================================
--
--  اختاره صاحبُ المنصّة بعد أن عُرضت عليه ثلاثةُ معانٍ للحذف: «يُمحى من
--  القاعدة نهائيّاً».
--
--  ── ولماذا دالّةٌ لا سياسةُ حذفٍ على الجدول ─────────────────────────────
--
--  سياسةُ `delete` تعطي العميلَ محوَ صفٍّ فيه اسمُ مزوّدٍ وعنوانُ عرسٍ
--  ومبالغُ — بلا أن يُسأل أحدٌ عمّا تعلّق به. والشروطُ التي تحته لا تُكتب
--  في سياسة: وجودُ مدفوعاتٍ، ودخولُه تسويةً، ونزاعٌ مفتوح. فدالّةٌ
--  `security definer` تفحص ثمّ تمحو، ولا يُمنح العميلُ حذفاً مباشراً.
--
--  ── وثلاثةُ أبوابٍ مغلقةٌ عمداً ────────────────────────────────────────
--
--    ١. **ما دُفع فيه شيء.** `payments.booking_id` مرجعُه `on delete set
--       null` — فمحوُ الحجز يترك مبلغاً مدفوعاً **بلا حجزٍ يُنسب إليه**،
--       ولا يُعرف بعدَها لمن دُفع ولا عمّاذا. فيُمنع.
--    ٢. **وما دخل تسويةً.** `settlement_items.booking_id` مرجعُه
--       `on delete restrict` — والقاعدةُ نفسُها سترفض. فيُقال له لماذا
--       بالعربيّة بدل خطأِ مفتاحٍ أجنبيّ.
--    ٣. **وما فيه نزاعٌ مفتوح.** الحجزُ سندُ النزاع، ومحوُه يُسقط ما
--       تنظر فيه الإدارة.
--
--  ── وما يذهب معه ──────────────────────────────────────────────────────
--
--  التقييمُ والمحادثةُ يشيران إليه بـ`cascade`/`set null` فيذهبان أو
--  ينفصلان. وهذا مقصود: حجزٌ ممحوٌّ لا تقييمَ له.
--
--  ── ويُمحى من الطرفين ─────────────────────────────────────────────────
--
--  **وهذا قيل لصاحب المنصّة قبل أن يختار**: الصفُّ واحدٌ، فمحوُه يُذهبه من
--  سجلّ مقدّم الخدمة ومن لوحة التحكّم كذلك.

create or replace function public.api_delete_booking(p_booking_id uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  booking public.bookings;
  paid    integer;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  -- **وصاحبُه وحدَه** — أو من يملك كتابةَ الحجوزات في الإدارة.
  if booking.user_id is distinct from me and not public.can_write_area('bookings') then
    raise exception 'لا تملك صلاحية حذف هذا الحجز';
  end if;

  select count(*) into paid from public.payments where booking_id = booking.id;
  if paid > 0 or coalesce(booking.paid_amount, 0) > 0 then
    raise exception 'لا يُحذف حجزٌ دخله مال. ألغِ الحجز ليُحسب ما يُستردّ لك.';
  end if;

  if exists (select 1 from public.settlement_items where booking_id = booking.id) then
    raise exception 'لا يُحذف حجزٌ دخل تسوية.';
  end if;

  if exists (
    select 1 from public.disputes
     where booking_id = booking.id
       and status in ('open', 'investigating')
  ) then
    raise exception 'لا يُحذف حجزٌ عليه نزاعٌ مفتوح.';
  end if;

  delete from public.bookings where id = booking.id;
  return 'deleted';
end $$;

revoke all on function public.api_delete_booking(uuid) from public, anon;
grant execute on function public.api_delete_booking(uuid) to authenticated;

select 'حذف الحجز ✓' as "تمّ";
