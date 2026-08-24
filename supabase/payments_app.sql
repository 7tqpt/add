-- ============================================================================
--  الدفع من التطبيق: العميل يُبلّغ بحوالته، والإدارة تؤكّدها
--
--  شغّله في محرّر SQL بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا:**
--
--  جدول `payments` ودالّة `api_confirm_payment` وسلّم الاسترجاع في المخطّط منذ
--  أوّل يوم، واللوحة تعرض المدفوعات — **ولم يكن للعميل سبيلٌ إلى دفع ريالٍ
--  واحد**. يحجز، ويُحسب له عربون، ثم يقف كل شيء. ومنصّةُ حجوزاتٍ لا يتحرّك
--  فيها المال معرضٌ لا سوق.
--
--  **ولماذا الحوالةُ لا بوّابةُ دفع:**
--
--  البوّابة تحتاج حساباً تجارياً وعقداً ومفاتيحَ من مزوّدها — ولا يُبنى تكاملٌ
--  مع طرفٍ لم يُفتح معه حساب. وهذا المسار يعمل **اليوم** بما هو قائم في
--  اليمن: يحوّل العميل على رقم المنصّة (جوالي أو الكريمي أو حوالة بنكية) ثم
--  يُبلّغ من التطبيق، فتؤكّد الإدارة من اللوحة.
--
--  وحين يُفتح حساب بوّابة يبقى كلُّ ما هنا كما هو: `api_confirm_payment`
--  محفوظةٌ لمفتاح الخدمة، فيناديها خطّافُ البوّابة بدل يد المسؤول — والصفوف
--  والحالات والإشعارات هي هي.
--
--  **وما لا يُترك للتطبيق: المبلغ.** يحسبه الخادم من الحجز نفسه. ولو قبِله
--  من العميل لأمكن دفع عربون قاعةٍ بريالٍ واحد.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. أين يُحوَّل المال — إعداداتٌ يملؤها المسؤول من اللوحة
--
--    في `app_settings` لا في الشيفرة: الأرقام تتغيّر، وتغييرُها في الشيفرة
--    يعني بناءً جديداً وتحديثاً على كل جهاز.
-- ----------------------------------------------------------------------------
alter table public.app_settings
  add column if not exists pay_jawali  text not null default '',
  add column if not exists pay_kuraimi text not null default '',
  add column if not exists pay_bank    text not null default '',
  add column if not exists pay_note    text not null default '';

comment on column public.app_settings.pay_jawali is 'رقم محفظة جوالي الذي يُحوَّل إليه.';
comment on column public.app_settings.pay_kuraimi is 'حساب الكريمي.';
comment on column public.app_settings.pay_bank is 'اسم البنك ورقم الحساب.';
comment on column public.app_settings.pay_note is 'ملاحظةٌ تظهر للعميل مع أرقام التحويل.';

-- ----------------------------------------------------------------------------
-- ٢. إبلاغُ العميل بحوالته
--
--    ينشئ عمليةً **معلّقة** لا مدفوعة: المال لم يصل حتى يراه المسؤول في
--    حسابه. وعمليةٌ تُعلَّم «مدفوعة» بكلمة العميل تفتح باب حجزٍ بلا مال.
-- ----------------------------------------------------------------------------
create or replace function public.api_submit_payment(
  p_booking_id uuid,
  p_method     text,
  p_kind       text default 'deposit',
  p_sender_ref text default ''
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  bk      public.bookings;
  due     numeric(12, 2);
  pay     public.payments;
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;

  select * into bk from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  -- `is distinct from` لا `<>`: صاحبُ الحجز قد يكون فارغاً (حُذف حسابه)،
  -- و`null <> me` تُعطي `null` لا `true` — فيمرّ الشرط ويدفع الغريبُ عن حجزٍ
  -- لا صاحب له. وهذا ما كشفه الاختبار.
  if bk.user_id is distinct from me then
    raise exception 'هذا الحجز ليس لك';
  end if;
  if bk.status in ('cancelled', 'rejected', 'expired') then
    raise exception 'الحجز لم يعد قائماً';
  end if;

  if p_method not in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet', 'wallet', 'card') then
    raise exception 'وسيلة دفع غير معروفة';
  end if;

  -- **المبلغ من الحجز لا من التطبيق.** والعربونُ ما بقي منه، والباقي ما بقي
  -- من الإجمالي — فمن دفع عربونه ثم أراد الإكمال لا يُطالَب به مرّتين.
  due := case p_kind
           when 'deposit' then bk.deposit_amount - bk.paid_amount
           else bk.total_price - bk.paid_amount
         end;
  if due <= 0 then
    raise exception 'لا مبلغ مستحقّاً على هذا الحجز';
  end if;

  -- عمليةٌ معلّقة واحدة لكل حجز: من ضغط الزرّ مرّتين لا يُنشئ حوالتين تُربكان
  -- المسؤول ويُحتسب إحداهما مرّتين.
  if exists (
    select 1 from public.payments
     where booking_id = bk.id and status = 'pending'
  ) then
    raise exception 'لديك إبلاغٌ سابق قيد التأكيد على هذا الحجز';
  end if;

  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, method, status, gateway_ref
  ) values (
    'PAY-' || to_char(now(), 'YYYY') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    bk.user_id, bk.user_name, bk.provider_id, bk.provider_name,
    bk.id, bk.reference, p_kind,
    case p_kind when 'deposit' then 'عربون الحجز' else 'إكمال مبلغ الحجز' end,
    due, p_method, 'pending', btrim(coalesce(p_sender_ref, ''))
  ) returning * into pay;

  return pay;
end;
$$;

-- ----------------------------------------------------------------------------
-- ٣. تأكيدُ الإدارة من اللوحة
--
--    `api_confirm_payment` **محفوظةٌ لمفتاح الخدمة** — لخطّاف بوّابة الدفع
--    حين تُربط. وهذه بابُ المسؤول إليها: تتحقّق من صلاحيته ثم تناديها، فلا
--    يُكتب حسابُ المبلغ وتحديثُ الحجز والإشعار مرّتين في موضعين يفترقان.
-- ----------------------------------------------------------------------------
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
  if not public.can_write() then
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

-- ----------------------------------------------------------------------------
-- ٤. ردُّ الإبلاغ
--
--    حوالةٌ لم تصل، أو رقمٌ خاطئ. وتُعلَّم `failed` لا تُحذف: العميل يجب أن
--    يرى أن إبلاغه رُدّ ولماذا، لا أن يختفي بلا أثر.
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_reject_payment(
  p_payment_id uuid,
  p_reason     text default ''
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  pay public.payments;
begin
  if not public.can_write() then
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

grant execute on function
  public.api_submit_payment(uuid, text, text, text),
  public.api_admin_confirm_payment(uuid, text, text),
  public.api_admin_reject_payment(uuid, text)
to authenticated;

commit;

-- ----------------------------------------------------------------------------
-- تحقّق
-- ----------------------------------------------------------------------------
select 'أعمدة التحويل' as البند,
       count(*)::text as الواقع, '4' as المتوقع
  from information_schema.columns
 where table_schema = 'public' and table_name = 'app_settings'
   and column_name in ('pay_jawali', 'pay_kuraimi', 'pay_bank', 'pay_note')
union all
select 'الدوال', count(*)::text, '3'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('api_submit_payment', 'api_admin_confirm_payment',
                     'api_admin_reject_payment');
