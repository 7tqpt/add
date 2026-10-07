-- ============================================================================
--  «رصيد فرحتي»: الاسترجاعُ يدخل رصيدَ العميل، فيدفع منه أو يسحبه
--
--  شغّله بعد `security_fixes.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما طلبه صاحبُ المنصّة:** «يكون في محفظة رصيد فرحتي، عند الغاء الحجز يرجع
--  المبلغ للعميل، ويكون في خيار سحب المال ويرفع للادرة والادارة تسترجع المال
--  للعميل». ثمّ اختار:
--
--    • **الاسترجاعُ المحسوبُ ينتظر موافقتَه** — الإلغاءُ يحسبه بسلّم الإلغاء،
--      ورفضُ المزوّد يحسبه كاملاً، لكنّه لا يدخل الرصيدَ حتى يعتمده مسؤولٌ.
--      أمّا زرُّ «ردّ المبلغ» في اللوحة فهو نفسُه قرارُ المسؤول، فيدخل فوراً.
--    • **ويدفع العميلُ من رصيده** حجوزاتِه القادمة، فيتأكّد الدفعُ بلا انتظار.
--    • **ولا يُسحب إلّا إلى حسابٍ دفع منه** — «عشن غسل الامول قد ربما في عميل
--      دفع عبر حساب ويريد يسحب المال الي حساب الثاني». فيُرفض الطلبُ هنا، في
--      القاعدة، لا في التطبيق وحده.
--
--  **ولمقدّم الخدمة رصيدٌ كذلك** («باقي مقدم الخدمة محفظة رصيد فرحتي»)، واختار:
--  صافي الحجز يدخله **حين تعتمد الإدارةُ التنفيذ**، ويُسحب **إلى حسابٍ مسجَّلٍ
--  وثّقته الإدارة** وحدَه، و«مستحقات الشركاء» تبقى سجلّاً لما قبل الرصيد.
--
--  **والرصيدُ لا يُشحن.** لا يدخله مالٌ إلّا من استرجاع حجزٍ دُفع فعلاً —
--  فهو ليس محفظةً يودِع فيها الناسُ أموالَهم، بل موضعٌ يبقى فيه ما يُردّ لهم.
--
--  **والرصيدُ مجموعُ حركاتٍ لا عمودٌ يُعدَّل.** عمودٌ يُزاد ويُنقص يضيع أثرُه
--  عند أوّل خطأ؛ والحركاتُ دفترٌ: كلُّ ريالٍ فيه يعود إلى دفعةٍ أو طلبِ سحب.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. رقمُ الحساب الذي دُفع منه — عمودٌ لا يُكتب فوقه
--
--    كان يُحفظ في `gateway_ref`، والمسؤولُ حين يؤكّد يكتب فيه رقمَ العملية من
--    كشف حسابه فيضيع رقمُ العميل. والمطابقةُ عند السحب تحتاجه كما كتبه.
-- ----------------------------------------------------------------------------
alter table public.payments
  add column if not exists payer_account text not null default '';

comment on column public.payments.payer_account is
  'رقم الحساب أو المحفظة الذي حوّل منه العميل — يُطابَق به طلبُ السحب.';

-- ما سبق هذا الملفّ: رقمُ العميل في `gateway_ref` إن كانت الوسيلةُ تحويلاً.
update public.payments
   set payer_account = btrim(gateway_ref)
 where payer_account = ''
   and btrim(gateway_ref) <> ''
   and method in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet')
   and kind <> 'refund';

-- ----------------------------------------------------------------------------
-- ٢. توحيدُ الرقم للمطابقة
--
--    «٧٧٧ ١٢٣ ٤٥٦» و«+967777123456» و«777123456» حسابٌ واحد. فتُحوَّل الأرقامُ
--    العربيّة، ويُرمى ما ليس رقماً، ومفتاحُ اليمن في أوّله.
-- ----------------------------------------------------------------------------
create or replace function public.wallet_norm(p_account text)
returns text language sql immutable set search_path = public as $$
  select regexp_replace(
           regexp_replace(
             translate(coalesce(p_account, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'),
             '\D', '', 'g'),
           '^(00)?967(?=\d{9}$)', '')
$$;

-- ----------------------------------------------------------------------------
-- ٣. الدفتر: حركاتُ الرصيد، وطلباتُ السحب
-- ----------------------------------------------------------------------------
create sequence if not exists public.wallet_withdrawal_seq;

create table if not exists public.wallet_withdrawals (
  id          uuid primary key default gen_random_uuid(),
  reference   text not null unique,
  user_id     uuid references public.app_users (id) on delete set null,
  -- طلبُ مقدّم خدمةٍ لا عميل — وحسابُه حسابُه المسجَّل الموثَّق.
  provider_id uuid references public.service_providers (id) on delete set null,
  amount      numeric(12, 2) not null check (amount > 0),
  method      text not null
              check (method in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet')),
  account     text not null check (btrim(account) <> ''),
  -- الدفعةُ التي طابقها الرقم — يراها المسؤولُ بجانب الطلب.
  matched_payment_id uuid references public.payments (id) on delete set null,
  status      text not null default 'pending'
              check (status in ('pending', 'paid', 'rejected')),
  note        text not null default '',
  created_at  timestamptz not null default now(),
  decided_at  timestamptz,
  decided_by  uuid,
  constraint decided_has_time check ((status = 'pending') = (decided_at is null))
);

create index if not exists wallet_withdrawals_status_idx
  on public.wallet_withdrawals (status, created_at desc);
create index if not exists wallet_withdrawals_user_idx
  on public.wallet_withdrawals (user_id, created_at desc);

create table if not exists public.wallet_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references public.app_users (id) on delete set null,
  -- رصيدُ مقدّم خدمةٍ لا عميل.
  provider_id   uuid references public.service_providers (id) on delete set null,
  -- موجبٌ داخل، وسالبٌ خارج.
  amount        numeric(12, 2) not null check (amount <> 0),
  kind          text not null
                check (kind in ('refund', 'earning', 'payment', 'withdrawal', 'withdrawal_reversal')),
  booking_id    uuid references public.bookings (id) on delete set null,
  payment_id    uuid references public.payments (id) on delete set null,
  withdrawal_id uuid references public.wallet_withdrawals (id) on delete set null,
  note          text not null default '',
  created_at    timestamptz not null default now(),
  -- الاتجاهُ من النوع: لا استرجاعَ سالبٌ ولا سحبَ موجب.
  constraint entry_sign check (
    (kind in ('refund', 'earning', 'withdrawal_reversal') and amount > 0)
    or (kind in ('payment', 'withdrawal') and amount < 0))
);

-- **وما لُصق قبل رصيد المزوّد** يُكمَل هنا: العمودان، والنوعُ الجديد في القيدين.
alter table public.wallet_withdrawals
  add column if not exists provider_id uuid references public.service_providers (id) on delete set null;
alter table public.wallet_entries
  add column if not exists provider_id uuid references public.service_providers (id) on delete set null;
alter table public.wallet_entries drop constraint if exists wallet_entries_kind_check;
alter table public.wallet_entries add constraint wallet_entries_kind_check
  check (kind in ('refund', 'earning', 'payment', 'withdrawal', 'withdrawal_reversal'));
alter table public.wallet_entries drop constraint if exists entry_sign;
alter table public.wallet_entries add constraint entry_sign check (
  (kind in ('refund', 'earning', 'withdrawal_reversal') and amount > 0)
  or (kind in ('payment', 'withdrawal') and amount < 0));

create index if not exists wallet_entries_provider_idx
  on public.wallet_entries (provider_id, created_at desc) where provider_id is not null;
-- **وحجزٌ واحدٌ لا يدخل رصيدَ مزوّده مرّتين** — يُعاد فتحُه ثمّ يُنفَّذ ثانيةً.
create unique index if not exists wallet_entries_earning_once_idx
  on public.wallet_entries (booking_id) where kind = 'earning';

create index if not exists wallet_entries_user_idx
  on public.wallet_entries (user_id, created_at desc);
create index if not exists wallet_entries_booking_idx
  on public.wallet_entries (booking_id) where kind = 'refund';

-- **ودفعةٌ واحدةٌ لا تدخل الرصيدَ مرّتين** — مسؤولان يعتمدان معاً، أو يُضغط
-- «ردّ المبلغ» بعد اعتماد استرجاعها.
create unique index if not exists wallet_entries_refund_once_idx
  on public.wallet_entries (payment_id) where kind = 'refund';

alter table public.wallet_entries enable row level security;
alter table public.wallet_withdrawals enable row level security;
revoke all on public.wallet_entries, public.wallet_withdrawals from public, anon, authenticated;
grant select on public.wallet_entries, public.wallet_withdrawals to authenticated;

drop policy if exists wallet_entries_owner_read on public.wallet_entries;
create policy wallet_entries_owner_read on public.wallet_entries
  for select to authenticated
  using (user_id = public.current_app_user() or provider_id = public.current_provider()
         or public.can_read_area('finance'));

drop policy if exists wallet_withdrawals_owner_read on public.wallet_withdrawals;
create policy wallet_withdrawals_owner_read on public.wallet_withdrawals
  for select to authenticated
  using (user_id = public.current_app_user() or provider_id = public.current_provider()
         or public.can_read_area('finance'));

-- ----------------------------------------------------------------------------
-- ٤. حالُ الاسترجاع: بانتظار الاعتماد، أو دخل الرصيد، أو رُفض
--
--    `legacy` لما سبق هذا الملفّ: استرجاعاتٌ قديمةٌ رُدّت بيد صاحب المنصّة أو
--    لم تُردّ — لا يعرف الملفُّ أيَّهما، فلا يُدخلها رصيداً ولا يعرضها للاعتماد.
-- ----------------------------------------------------------------------------
alter table public.payments
  add column if not exists wallet_state text
    check (wallet_state in ('pending', 'credited', 'declined', 'legacy'));

update public.payments set wallet_state = 'legacy'
 where kind = 'refund' and wallet_state is null;

-- الإلغاءُ ورفضُ المزوّد يُدخلان صفَّ `refund` بأنفسهما (`api_cancel_booking`
-- و`api_respond_to_booking`) — فيُعلَّم هنا «بانتظار الاعتماد» بلا لمسِ تلك
-- الدوالّ، وهي في حزمة التحصين.
create or replace function public.wallet_mark_refund()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.kind = 'refund' and new.wallet_state is null then
    new.wallet_state := 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists payments_wallet_mark_refund on public.payments;
create trigger payments_wallet_mark_refund
  before insert on public.payments
  for each row execute function public.wallet_mark_refund();

-- ----------------------------------------------------------------------------
-- ٥. القيد: إدخالُ استرجاعٍ في الرصيد
--
--    **وسقفُه ما دُفع في الحجز.** مجموعُ ما دخل الرصيدَ من حجزٍ لا يتجاوز
--    `paid_amount` — فلا يُردّ عن حجزٍ واحدٍ مرّتين، باستعادةٍ تلقائيّةٍ ثمّ
--    بزرّ «ردّ المبلغ» على عربونه.
-- ----------------------------------------------------------------------------
create or replace function public.wallet_credit_refund(
  p_payment public.payments,
  p_amount  numeric,
  p_note    text default ''
)
returns numeric
language plpgsql security definer set search_path = public as $$
declare
  room   numeric(12, 2);
  credit numeric(12, 2);
begin
  if p_payment.user_id is null or coalesce(p_amount, 0) <= 0 then
    return 0;
  end if;

  if p_payment.booking_id is not null then
    select greatest(b.paid_amount - coalesce((
             select sum(e.amount) from public.wallet_entries e
              where e.booking_id = b.id and e.kind = 'refund'), 0), 0)
      into room
      from public.bookings b where b.id = p_payment.booking_id;
    credit := least(p_amount, coalesce(room, 0));
  else
    credit := p_amount;
  end if;

  if credit <= 0 then
    return 0;
  end if;

  insert into public.wallet_entries (user_id, amount, kind, booking_id, payment_id, note)
  values (p_payment.user_id, credit, 'refund', p_payment.booking_id, p_payment.id,
          coalesce(nullif(btrim(p_note), ''),
                   'استرجاع — ' || coalesce(nullif(p_payment.booking_reference, ''), 'حجز')))
  on conflict (payment_id) where kind = 'refund' do nothing;

  if not found then
    return 0;
  end if;

  perform public.notify_user(
    p_payment.user_id, 'payment', 'دخل رصيدَك مبلغٌ مسترجَع',
    'أُضيف ' || trim(to_char(credit, 'FM999999999')) || ' ريال إلى «رصيد فرحتي» عن '
      || coalesce(nullif(p_payment.booking_reference, ''), 'حجزك') || '.',
    jsonb_build_object('payment_id', p_payment.id, 'booking_id', p_payment.booking_id)
  );
  return credit;
end;
$$;

revoke all on function public.wallet_credit_refund(public.payments, numeric, text)
  from public, anon, authenticated;

-- «ردّ المبلغ» في اللوحة (`api_admin_refund_payment`) يقلب الدفعةَ `refunded`:
-- قرارُ مسؤولٍ، فيدخل الرصيدَ فوراً. ودفعةُ الرصيد نفسُها تعود إليه كذلك.
create or replace function public.wallet_on_refund()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind <> 'refund' and old.status = 'paid' and new.status = 'refunded' then
    perform public.wallet_credit_refund(new, new.amount, 'ردّته الإدارة — '
      || coalesce(nullif(new.booking_reference, ''), new.reference));
  end if;
  return new;
end;
$$;

drop trigger if exists payments_wallet_on_refund on public.payments;
create trigger payments_wallet_on_refund
  after update of status on public.payments
  for each row execute function public.wallet_on_refund();

-- ----------------------------------------------------------------------------
-- ٦. الرصيد
-- ----------------------------------------------------------------------------
create or replace function public.wallet_balance(p_user uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::numeric(12, 2)
    from public.wallet_entries where user_id = p_user
$$;

revoke all on function public.wallet_balance(uuid) from public, anon, authenticated;

-- حسابٌ واحدٌ في الدفتر في اللحظة الواحدة: سحبان معاً لا يمرّان على رصيدٍ
-- واحد، ولا دفعٌ وسحب.
create or replace function public.wallet_lock(p_user uuid)
returns void language sql security definer set search_path = public as $$
  select pg_advisory_xact_lock(hashtextextended('wallet:' || p_user::text, 0))
$$;

revoke all on function public.wallet_lock(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- ٧. إبلاغُ الحوالة — ورقمُ المحوِّل صار إجباريّاً
--
--    هي `api_submit_payment` من `payments_app.sql` بفرقين: لا إبلاغَ بلا رقم
--    الحساب الذي حُوِّل منه، ويُحفظ في `payer_account` الذي لا يُكتب فوقه.
--    فبلا رقمٍ لا مطابقة، وبلا مطابقةٍ لا سحب.
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
  sender  text := btrim(coalesce(p_sender_ref, ''));
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;

  select * into bk from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if bk.user_id is distinct from me then
    raise exception 'هذا الحجز ليس لك';
  end if;
  if bk.status in ('cancelled', 'rejected', 'expired') then
    raise exception 'الحجز لم يعد قائماً';
  end if;

  if p_method not in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet') then
    raise exception 'وسيلة دفع غير معروفة';
  end if;

  if length(public.wallet_norm(sender)) < 6 then
    raise exception 'اكتب رقم الحساب الذي حوّلت منه — إليه يُرجَع أيُّ مبلغٍ تسترجعه';
  end if;

  due := case p_kind
           when 'deposit' then bk.deposit_amount - bk.paid_amount
           else bk.total_price - bk.paid_amount
         end;
  if due <= 0 then
    raise exception 'لا مبلغ مستحقّاً على هذا الحجز';
  end if;

  if exists (
    select 1 from public.payments
     where booking_id = bk.id and status = 'pending'
  ) then
    raise exception 'لديك إبلاغٌ سابق قيد التأكيد على هذا الحجز';
  end if;

  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, method, status, gateway_ref, payer_account
  ) values (
    'PAY-' || to_char(now(), 'YYYY') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    bk.user_id, bk.user_name, bk.provider_id, bk.provider_name,
    bk.id, bk.reference, p_kind,
    case p_kind when 'deposit' then 'عربون الحجز' else 'إكمال مبلغ الحجز' end,
    due, p_method, 'pending', sender, sender
  ) returning * into pay;

  return pay;
end;
$$;

-- ----------------------------------------------------------------------------
-- ٨. الدفعُ من الرصيد — يتأكّد فوراً
--
--    المبلغُ من الحجز لا من التطبيق، كالحوالة تماماً. ولا يُدفع جزءٌ: رصيدٌ لا
--    يغطّي المستحقَّ يُقال له ذلك، وتبقى الحوالةُ له.
-- ----------------------------------------------------------------------------
create or replace function public.api_pay_from_wallet(
  p_booking_id uuid,
  p_kind       text default 'deposit'
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  bk   public.bookings;
  due  numeric(12, 2);
  bal  numeric(12, 2);
  pay  public.payments;
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  perform public.wallet_lock(me);

  select * into bk from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if bk.user_id is distinct from me then
    raise exception 'هذا الحجز ليس لك';
  end if;
  if bk.status in ('cancelled', 'rejected', 'expired', 'completed') then
    raise exception 'الحجز لم يعد قائماً';
  end if;
  if p_kind not in ('deposit', 'balance') then
    raise exception 'نوع دفعٍ غير معروف';
  end if;

  due := case p_kind
           when 'deposit' then bk.deposit_amount - bk.paid_amount
           else bk.total_price - bk.paid_amount
         end;
  if due <= 0 then
    raise exception 'لا مبلغ مستحقّاً على هذا الحجز';
  end if;

  -- حوالةٌ مُبلَّغٌ عنها لم تُؤكَّد بعد: لو دُفع من الرصيد معها لدُفع مرّتين.
  if exists (select 1 from public.payments where booking_id = bk.id and status = 'pending') then
    raise exception 'لديك إبلاغٌ سابق قيد التأكيد على هذا الحجز';
  end if;

  bal := public.wallet_balance(me);
  if bal < due then
    raise exception 'رصيدك % ريال لا يكفي — المستحقّ % ريال',
      trim(to_char(bal, 'FM999999999')), trim(to_char(due, 'FM999999999'));
  end if;

  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, method, status
  ) values (
    'PAY-' || to_char(now(), 'YYYY') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    bk.user_id, bk.user_name, bk.provider_id, bk.provider_name,
    bk.id, bk.reference, p_kind,
    case p_kind when 'deposit' then 'عربون الحجز — من رصيد فرحتي'
                else 'إكمال مبلغ الحجز — من رصيد فرحتي' end,
    due, 'wallet', 'pending'
  ) returning * into pay;

  insert into public.wallet_entries (user_id, amount, kind, booking_id, payment_id, note)
  values (me, -due, 'payment', bk.id, pay.id,
          case p_kind when 'deposit' then 'عربون ' else 'إكمال ' end || bk.reference);

  -- التأكيدُ بالدالّة التي يؤكّد بها المسؤولُ والخطّاف — فيُحدَّث الحجزُ ويُشعَر
  -- العميلُ من موضعٍ واحد.
  pay := public.api_confirm_payment(pay.id, 'رصيد فرحتي', 'wallet');

  perform public.notify_provider(
    pay.provider_id, 'payment', 'وصلت دفعة',
    'استلمت المنصّة دفعةً على الحجز ' || pay.booking_reference || '.',
    jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
  );

  return pay;
end;
$$;

-- ----------------------------------------------------------------------------
-- ٩. طلبُ السحب — **إلى حسابٍ دُفع منه، وإلّا فلا**
-- ----------------------------------------------------------------------------
create or replace function public.api_request_withdrawal(
  p_amount  numeric,
  p_method  text,
  p_account text
)
returns public.wallet_withdrawals
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  bal     numeric(12, 2);
  acct    text := public.wallet_norm(p_account);
  matched uuid;
  wd      public.wallet_withdrawals;
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  perform public.wallet_lock(me);

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'اكتب مبلغاً أكبر من صفر';
  end if;
  if p_method not in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet') then
    raise exception 'وسيلة سحبٍ غير معروفة';
  end if;
  if length(acct) < 6 then
    raise exception 'اكتب رقم الحساب الذي دفعت منه';
  end if;

  -- **المطابقةُ بالرقم موحَّداً** على كلّ دفعةٍ دفعها هذا العميلُ تحويلاً.
  select p.id into matched
    from public.payments p
   where p.user_id = me
     and p.kind <> 'refund'
     and p.method <> 'wallet'
     and p.status in ('paid', 'refunded')
     and public.wallet_norm(p.payer_account) = acct
   order by p.created_at desc
   limit 1;

  if matched is null then
    raise exception 'اسحب إلى الحساب الذي دفعت منه — هذا الرقم ليس في سجلّ دفعك. وإن أُغلق حسابُك فتواصل مع الدعم';
  end if;

  bal := public.wallet_balance(me);
  if p_amount > bal then
    raise exception 'المبلغ أكبر من رصيدك المتاح (% ريال)', trim(to_char(bal, 'FM999999999'));
  end if;

  insert into public.wallet_withdrawals (reference, user_id, amount, method, account, matched_payment_id)
  values ('WD-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.wallet_withdrawal_seq')::text, 4, '0'),
          me, p_amount, p_method, btrim(p_account), matched)
  returning * into wd;

  -- **يُحجز من الرصيد فور الطلب** — فلا يُدفع به حجزٌ وهو في طريقه للسحب.
  insert into public.wallet_entries (user_id, amount, kind, withdrawal_id, note)
  values (me, -p_amount, 'withdrawal', wd.id, 'طلب سحب ' || wd.reference);

  return wd;
end;
$$;

-- ----------------------------------------------------------------------------
-- ١٠. الإدارة: حوّلتُ المبلغ، أو رفض
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_decide_withdrawal(
  p_id   uuid,
  p_paid boolean,
  p_note text default ''
)
returns public.wallet_withdrawals
language plpgsql security definer set search_path = public as $$
declare
  wd public.wallet_withdrawals;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية طلبات السحب';
  end if;
  if not p_paid and btrim(coalesce(p_note, '')) = '' then
    raise exception 'اكتب سبب الرفض — يصل العميل';
  end if;

  -- `status = 'pending'` هو ما يمنع قرارين: مسؤولان يضغطان معاً، فالثاني لا
  -- يجد صفّاً.
  update public.wallet_withdrawals
     set status = case when p_paid then 'paid' else 'rejected' end,
         note = btrim(coalesce(p_note, '')),
         decided_at = now(),
         decided_by = auth.uid()
   where id = p_id and status = 'pending'
  returning * into wd;

  if not found then
    raise exception 'لا يوجد طلبُ سحبٍ معلّقٌ بهذا الرقم — قد يكون قُرّر من قبل';
  end if;

  if not p_paid then
    -- الرفضُ يُعيد المبلغ إلى رصيد صاحبه — عميلاً كان أو مقدّمَ خدمة.
    insert into public.wallet_entries (user_id, provider_id, amount, kind, withdrawal_id, note)
    values (wd.user_id, wd.provider_id, wd.amount, 'withdrawal_reversal', wd.id,
            'رُفض طلب السحب ' || wd.reference);
  end if;

  if wd.provider_id is not null then
    perform public.notify_provider(
      wd.provider_id, 'payment',
      case when p_paid then 'حُوِّل مبلغُ السحب' else 'لم يُقبل طلبُ السحب' end,
      case when p_paid
           then 'حوّلنا ' || trim(to_char(wd.amount, 'FM999999999')) || ' ريال إلى ' || wd.account || '.'
           else btrim(p_note) || ' — عاد المبلغ إلى رصيدك.' end,
      jsonb_build_object('withdrawal_id', wd.id));
  else
    perform public.notify_user(
      wd.user_id, 'payment',
      case when p_paid then 'حُوِّل مبلغُ السحب' else 'لم يُقبل طلبُ السحب' end,
      case when p_paid
           then 'حوّلنا ' || trim(to_char(wd.amount, 'FM999999999')) || ' ريال إلى ' || wd.account || '.'
           else btrim(p_note) || ' — عاد المبلغ إلى رصيدك.' end,
      jsonb_build_object('withdrawal_id', wd.id));
  end if;

  return wd;
end;
$$;

-- طلباتُ السحب كما يراها المسؤول: مع اسم العميل، والدفعةِ التي طابقها،
-- والرقمِ كما في سجلّ تلك الدفعة.
create or replace function public.api_admin_withdrawals(p_status text default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_read_area('finance') then
    raise exception 'لا تملك صلاحية طلبات السحب';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r) order by r.created_at desc)
      from (
        select w.id, w.reference, w.amount, w.method, w.account, w.status, w.note,
               w.created_at, w.decided_at,
               case when w.provider_id is null then 'customer' else 'provider' end as party,
               coalesce(u.full_name, nullif(sp.business_name, ''), sp.full_name) as user_name,
               coalesce(u.phone, sp.phone) as user_phone,
               -- العميلُ يُطابَق بدفعةٍ دفعها، والمزوّدُ بحسابه المسجَّل الموثَّق.
               coalesce(p.reference, case when pa.provider_id is not null then 'حساب مسجَّل' end) as paid_reference,
               coalesce(p.payer_account, pa.account) as paid_account,
               coalesce(p.method, pa.method) as paid_method,
               p.booking_reference as paid_booking,
               case when w.provider_id is null
                    then public.wallet_norm(p.payer_account) = public.wallet_norm(w.account)
                    else pa.status = 'verified' and public.wallet_norm(pa.account) = public.wallet_norm(w.account)
               end as matched
          from public.wallet_withdrawals w
          left join public.app_users u on u.id = w.user_id
          left join public.service_providers sp on sp.id = w.provider_id
          left join public.provider_payout_accounts pa on pa.provider_id = w.provider_id
          left join public.payments p on p.id = w.matched_payment_id
         where p_status is null or w.status = p_status
      ) r), '[]'::jsonb);
end;
$$;

-- ----------------------------------------------------------------------------
-- ١١. الإدارة: اعتمادُ الاسترجاع المحسوب، أو رفضُه
--
--    الاعتمادُ يُدخل المبلغَ الرصيد — وللمسؤول أن ينقصه لا أن يزيده: الحسابُ
--    من سلّم الإلغاء سقف. والرفضُ يُعيد المبلغَ إلى الحجز (`refunded_amount`)
--    فيعود مستحقّاً لمقدّم الخدمة في التسوية كأنّه لم يُسترجع.
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_decide_refund(
  p_payment_id uuid,
  p_approve    boolean,
  p_amount     numeric default null,
  p_note       text default ''
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pay      public.payments;
  amount   numeric(12, 2);
  credited numeric(12, 2) := 0;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية الاسترجاع';
  end if;

  select * into pay from public.payments
   where id = p_payment_id and kind = 'refund' and wallet_state = 'pending'
   for update;
  if not found then
    raise exception 'لا يوجد استرجاعٌ بانتظار الاعتماد بهذا الرقم';
  end if;

  amount := coalesce(p_amount, pay.amount);
  if p_approve and (amount <= 0 or amount > pay.amount) then
    raise exception 'المبلغ بين ريالٍ و% ريال', trim(to_char(pay.amount, 'FM999999999'));
  end if;

  if p_approve then
    perform public.wallet_lock(pay.user_id);
    credited := public.wallet_credit_refund(pay, amount, btrim(coalesce(p_note, '')));
  end if;

  update public.payments
     set wallet_state = case when p_approve then 'credited' else 'declined' end,
         description = case when btrim(coalesce(p_note, '')) = '' then description
                            else description || ' — ' || btrim(p_note) end
   where id = pay.id;

  -- ما لم يدخل الرصيدَ لا يُعدّ مسترجَعاً من الحجز.
  if pay.booking_id is not null and credited < pay.amount then
    update public.bookings
       set refunded_amount = greatest(refunded_amount - (pay.amount - credited), 0)
     where id = pay.booking_id;
  end if;

  if not p_approve then
    perform public.notify_user(
      pay.user_id, 'payment', 'لم يُعتمد الاسترجاع',
      coalesce(nullif(btrim(p_note), ''), 'راجعت الإدارةُ إلغاءك ولم تعتمد استرجاعاً.')
        || ' — ' || coalesce(nullif(pay.booking_reference, ''), 'حجزك'),
      jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id));
  end if;

  return jsonb_build_object('payment_id', pay.id, 'credited', credited,
                            'state', case when p_approve then 'credited' else 'declined' end);
end;
$$;

create or replace function public.api_admin_pending_refunds()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_read_area('finance') then
    raise exception 'لا تملك صلاحية الاسترجاع';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r) order by r.created_at)
      from (
        select p.id, p.reference, p.amount, p.description, p.created_at,
               p.booking_id, p.booking_reference, p.user_name, p.provider_name,
               b.paid_amount, b.status as booking_status
          from public.payments p
          left join public.bookings b on b.id = p.booking_id
         where p.kind = 'refund' and p.wallet_state = 'pending'
      ) r), '[]'::jsonb);
end;
$$;

-- ----------------------------------------------------------------------------
-- ١٢. رصيدي — ما يعرضه التطبيق في «رصيد فرحتي»
-- ----------------------------------------------------------------------------
create or replace function public.api_my_wallet()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := public.current_app_user();
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  return jsonb_build_object(
    'balance', public.wallet_balance(me),
    'entries', coalesce((
      select jsonb_agg(row_to_json(r) order by r.created_at desc)
        from (
          select e.id, e.amount, e.kind, e.note, e.created_at,
                 b.reference as booking_reference,
                 w.reference as withdrawal_reference, w.status as withdrawal_status,
                 w.method as withdrawal_method, w.account as withdrawal_account
            from public.wallet_entries e
            left join public.bookings b on b.id = e.booking_id
            left join public.wallet_withdrawals w on w.id = e.withdrawal_id
           where e.user_id = me
           order by e.created_at desc
           limit 100
        ) r), '[]'::jsonb),
    -- استرجاعاتٌ محسوبةٌ لم تُعتمد بعد — يراها العميلُ فلا يظنّ أنّها ضاعت.
    'pending_refunds', coalesce((
      select sum(amount) from public.payments
       where user_id = me and kind = 'refund' and wallet_state = 'pending'), 0)
  );
end;
$$;

-- ============================================================================
-- ١٣. رصيدُ مقدّم الخدمة
--
--    «باقي مقدم الخدمة محفظة رصيد فرحتي» — واختار صاحبُ المنصّة:
--      • **صافي الحجز يدخل رصيدَه حين تعتمد الإدارةُ التنفيذ** — المقبوضُ ناقصاً
--        المردودَ والعمولة، فلا يُعطى ما لم تقبضه المنصّة.
--      • **ويُسحب إلى حسابٍ مسجَّلٍ وثّقته الإدارة** وحدَه، وكلُّ تغييرٍ فيه
--        يعيده «بانتظار التوثيق» — لغسل الأموال كسحب العميل.
--      • **و«مستحقات الشركاء» تبقى سجلّاً** لما نُفّذ قبل الرصيد: لا يُحتسب
--        فيها حجزٌ دخل رصيدَ مزوّده.
-- ============================================================================
create table if not exists public.provider_payout_accounts (
  provider_id uuid primary key references public.service_providers (id) on delete cascade,
  method      text not null
              check (method in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet')),
  account     text not null check (btrim(account) <> ''),
  holder_name text not null check (btrim(holder_name) <> ''),
  status      text not null default 'pending'
              check (status in ('pending', 'verified', 'rejected')),
  note        text not null default '',
  updated_at  timestamptz not null default now(),
  verified_at timestamptz,
  verified_by uuid,
  constraint verified_has_time check ((status = 'verified') = (verified_at is not null))
);

alter table public.provider_payout_accounts enable row level security;
revoke all on public.provider_payout_accounts from public, anon, authenticated;
grant select on public.provider_payout_accounts to authenticated;
drop policy if exists payout_accounts_owner_read on public.provider_payout_accounts;
create policy payout_accounts_owner_read on public.provider_payout_accounts
  for select to authenticated
  using (provider_id = public.current_provider() or public.can_read_area('finance'));

create or replace function public.wallet_provider_balance(p_provider uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::numeric(12, 2)
    from public.wallet_entries where provider_id = p_provider
$$;

revoke all on function public.wallet_provider_balance(uuid) from public, anon, authenticated;

-- صافي الحجز المقبوض — ما يُعطى للمزوّد منه.
create or replace function public.wallet_booking_net(b public.bookings)
returns numeric language sql immutable set search_path = public as $$
  select greatest(
           greatest(b.paid_amount - b.refunded_amount, 0)
           - least(b.commission_amount, greatest(b.paid_amount - b.refunded_amount, 0)),
           0)::numeric(12, 2)
$$;

-- **يدخل الرصيدَ حين يصير الحجزُ «منفَّذاً»** — من أيّ باب: اعتمادُ الإدارة
-- للتنفيذ (`completion_review.sql`) أو تعديلُ حاله من اللوحة. والمشغّلُ هو
-- الذي يضمن ذلك لا كلُّ باب على حدة.
create or replace function public.wallet_on_completed()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  net numeric(12, 2) := public.wallet_booking_net(new);
begin
  if new.status = 'completed' and old.status is distinct from 'completed'
     and new.provider_id is not null and net > 0
     -- ما احتُسب في تسويةٍ قديمة دُفع من هناك.
     and not exists (select 1 from public.settlement_items i where i.booking_id = new.id) then
    insert into public.wallet_entries (provider_id, amount, kind, booking_id, note)
    values (new.provider_id, net, 'earning', new.id,
            'حجزٌ منفَّذ — ' || new.reference)
    on conflict (booking_id) where kind = 'earning' do nothing;

    if found then
      perform public.notify_provider(
        new.provider_id, 'payment', 'دخل رصيدَك صافي حجز',
        'أُضيف ' || trim(to_char(net, 'FM999999999')) || ' ريال إلى «رصيد فرحتي» عن '
          || new.reference || ' — بعد عمولة المنصّة.',
        jsonb_build_object('booking_id', new.id));
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_wallet_on_completed on public.bookings;
create trigger bookings_wallet_on_completed
  after update of status on public.bookings
  for each row execute function public.wallet_on_completed();

-- حسابُ السحب — يكتبه المزوّد، **ولا يصلح للسحب حتى توثّقه الإدارة**.
-- وتغييرُه يعيده «بانتظار التوثيق»: حسابٌ موثَّقٌ يُبدَّل بصمتٍ بابُ سرقة.
create or replace function public.api_set_payout_account(
  p_method      text,
  p_account     text,
  p_holder_name text
)
returns public.provider_payout_accounts
language plpgsql security definer set search_path = public as $$
declare
  me  uuid := public.current_provider();
  row public.provider_payout_accounts;
begin
  if me is null then
    raise exception 'لمقدّمي الخدمة وحدهم';
  end if;
  if p_method not in ('jawali', 'kuraimi', 'bank_transfer', 'cash_wallet') then
    raise exception 'وسيلةٌ غير معروفة';
  end if;
  if length(public.wallet_norm(p_account)) < 6 then
    raise exception 'اكتب رقم الحساب كاملاً';
  end if;
  if btrim(coalesce(p_holder_name, '')) = '' then
    raise exception 'اكتب اسم صاحب الحساب كما هو عند البنك أو المحفظة';
  end if;

  insert into public.provider_payout_accounts (provider_id, method, account, holder_name)
  values (me, p_method, btrim(p_account), btrim(p_holder_name))
  on conflict (provider_id) do update
    set method = excluded.method, account = excluded.account,
        holder_name = excluded.holder_name, status = 'pending', note = '',
        updated_at = now(), verified_at = null, verified_by = null
  returning * into row;
  return row;
end;
$$;

create or replace function public.api_admin_verify_payout_account(
  p_provider_id uuid,
  p_approve     boolean,
  p_note        text default ''
)
returns public.provider_payout_accounts
language plpgsql security definer set search_path = public as $$
declare
  row public.provider_payout_accounts;
begin
  if not public.can_write_area('finance') then
    raise exception 'لا تملك صلاحية توثيق حسابات السحب';
  end if;
  if not p_approve and btrim(coalesce(p_note, '')) = '' then
    raise exception 'اكتب سبب الرفض — يصل مقدّم الخدمة';
  end if;

  update public.provider_payout_accounts
     set status = case when p_approve then 'verified' else 'rejected' end,
         note = btrim(coalesce(p_note, '')),
         verified_at = case when p_approve then now() end,
         verified_by = case when p_approve then auth.uid() end
   where provider_id = p_provider_id and status = 'pending'
  returning * into row;
  if not found then
    raise exception 'لا حسابَ ينتظر التوثيق لهذا المزوّد';
  end if;

  perform public.notify_provider(
    p_provider_id, 'payment',
    case when p_approve then 'وُثّق حسابُ السحب' else 'لم يُوثَّق حسابُ السحب' end,
    case when p_approve then 'صار ' || row.account || ' حسابَك للسحب من «رصيد فرحتي».'
         else btrim(p_note) end,
    jsonb_build_object('provider_id', p_provider_id));
  return row;
end;
$$;

create or replace function public.api_admin_payout_accounts(p_status text default 'pending')
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_read_area('finance') then
    raise exception 'لا تملك صلاحية حسابات السحب';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r) order by r.updated_at)
      from (
        select a.provider_id, a.method, a.account, a.holder_name, a.status, a.note, a.updated_at,
               coalesce(nullif(sp.business_name, ''), sp.full_name) as provider_name,
               sp.full_name as owner_name, sp.phone as provider_phone
          from public.provider_payout_accounts a
          join public.service_providers sp on sp.id = a.provider_id
         where p_status is null or a.status = p_status
      ) r), '[]'::jsonb);
end;
$$;

-- السحبُ — **إلى الحساب المسجَّل الموثَّق، وإلّا فلا**.
create or replace function public.api_request_provider_withdrawal(p_amount numeric)
returns public.wallet_withdrawals
language plpgsql security definer set search_path = public as $$
declare
  me  uuid := public.current_provider();
  acc public.provider_payout_accounts;
  bal numeric(12, 2);
  wd  public.wallet_withdrawals;
begin
  if me is null then
    raise exception 'لمقدّمي الخدمة وحدهم';
  end if;
  perform public.wallet_lock(me);

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'اكتب مبلغاً أكبر من صفر';
  end if;

  select * into acc from public.provider_payout_accounts where provider_id = me;
  if not found then
    raise exception 'سجّل حسابَ السحب أوّلاً — توثّقه الإدارة ثمّ تسحب إليه';
  end if;
  if acc.status <> 'verified' then
    raise exception 'حسابُ السحب لم يُوثَّق بعد — تراجعه الإدارة';
  end if;

  bal := public.wallet_provider_balance(me);
  if p_amount > bal then
    raise exception 'المبلغ أكبر من رصيدك المتاح (% ريال)', trim(to_char(bal, 'FM999999999'));
  end if;

  insert into public.wallet_withdrawals (reference, provider_id, amount, method, account)
  values ('WD-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.wallet_withdrawal_seq')::text, 4, '0'),
          me, p_amount, acc.method, acc.account)
  returning * into wd;

  insert into public.wallet_entries (provider_id, amount, kind, withdrawal_id, note)
  values (me, -p_amount, 'withdrawal', wd.id, 'طلب سحب ' || wd.reference);

  return wd;
end;
$$;

-- رصيدي — كما يعرضه التطبيقُ في وضع مقدّم الخدمة.
create or replace function public.api_my_provider_wallet()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := public.current_provider();
begin
  if me is null then
    raise exception 'لمقدّمي الخدمة وحدهم';
  end if;
  return jsonb_build_object(
    'balance', public.wallet_provider_balance(me),
    -- عرابينُ حجوزاتٍ مؤكَّدةٍ لم تُنفَّذ — صافيها، يدخل الرصيدَ بالتنفيذ.
    'pending', coalesce((
      select sum(public.wallet_booking_net(b)) from public.bookings b
       where b.provider_id = me and b.status = 'confirmed'), 0),
    'account', (select row_to_json(a) from public.provider_payout_accounts a where a.provider_id = me),
    'entries', coalesce((
      select jsonb_agg(row_to_json(r) order by r.created_at desc)
        from (
          select e.id, e.amount, e.kind, e.note, e.created_at,
                 b.reference as booking_reference,
                 w.reference as withdrawal_reference, w.status as withdrawal_status,
                 w.method as withdrawal_method, w.account as withdrawal_account
            from public.wallet_entries e
            left join public.bookings b on b.id = e.booking_id
            left join public.wallet_withdrawals w on w.id = e.withdrawal_id
           where e.provider_id = me
           order by e.created_at desc
           limit 100
        ) r), '[]'::jsonb)
  );
end;
$$;

-- «مستحقات الشركاء» سجلٌّ لما قبل الرصيد: نسخةُ `settlements.sql` بسطرٍ زائد
-- واحد — ما دخل رصيدَ مزوّده لا يُحتسب. (ويقيس `tests/wallet.test.mjs` أنّ
-- النسختين لا تفترقان إلّا به.)
create or replace function public.api_admin_build_settlements(
  p_from date, p_to date)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  made integer := 0;
  row record;
  sid uuid;
begin
  if not public.can_write_area('finance') then
    raise exception 'احتساب التسويات لمن يملك الكتابة في المال';
  end if;
  if p_to < p_from then
    raise exception 'نهاية الفترة قبل بدايتها';
  end if;

  for row in
    select b.provider_id,
           max(b.provider_name)                             as provider_name,
           -- المقبوض لا المستحقّ.
           sum(b.paid_amount - b.refunded_amount)           as gross,
           sum(b.commission_amount)                         as commission,
           array_agg(b.id)                                  as bookings
      from public.bookings b
     where b.status = 'completed'
       and b.provider_id is not null
       and b.event_date between p_from and p_to
       and b.paid_amount > b.refunded_amount
       and not exists (select 1 from public.settlement_items i where i.booking_id = b.id)
       -- ما دخل رصيدَ مزوّده لا يُحتسب في تسوية: دُفع له من الرصيد.
       and not exists (select 1 from public.wallet_entries e where e.booking_id = b.id and e.kind = 'earning')
     group by b.provider_id
  loop
    -- القيود تمنع سالباً وتمنع أن يتجاوز المجموعُ الإجمالي: عمولةٌ تفوق
    -- المقبوض تقع حين يُلغى حجزٌ جزئياً، فتُقصر على المقبوض ويصير الصافي صفراً.
    -- والاحتساب يجب أن يقف عند الصفر لا أن يسقط بقيد.
    declare
      gross numeric(14, 2) := greatest(row.gross, 0);
      comm  numeric(14, 2) := least(greatest(row.commission, 0), greatest(row.gross, 0));
    begin
      insert into public.settlements
             (reference, provider_id, provider_name, period_start, period_end,
              gross_amount, commission_amount, net_amount, status)
      values ('STL-' || to_char(p_to, 'YYYYMM') || '-' ||
                upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
              row.provider_id, row.provider_name, p_from, p_to,
              gross, comm, gross - comm, 'pending')
      returning id into sid;

      insert into public.settlement_items
             (settlement_id, booking_id, gross_amount, commission_amount, net_amount)
      select sid, b.id,
             b.paid_amount - b.refunded_amount,
             least(b.commission_amount, b.paid_amount - b.refunded_amount),
             greatest(b.paid_amount - b.refunded_amount - b.commission_amount, 0)
        from public.bookings b
       where b.id = any(row.bookings);

      -- ومقدّم الخدمة يُخبَر: مستحقٌّ لا يعلم به صاحبه لا يُطمئنه.
      perform public.notify_provider(
        row.provider_id, 'payment', 'صدرت تسوية مستحقّاتك',
        'صافي مستحقّك عن الفترة: ' || to_char(gross - comm, 'FM999G999G999') || ' ر.ي.',
        jsonb_build_object('settlement_id', sid)
      );

      made := made + 1;
    end;
  end loop;

  return made;
end $$;

revoke all on function
  public.api_set_payout_account(text, text, text),
  public.api_admin_verify_payout_account(uuid, boolean, text),
  public.api_admin_payout_accounts(text),
  public.api_request_provider_withdrawal(numeric),
  public.api_my_provider_wallet(),
  public.api_pay_from_wallet(uuid, text),
  public.api_request_withdrawal(numeric, text, text),
  public.api_admin_decide_withdrawal(uuid, boolean, text),
  public.api_admin_withdrawals(text),
  public.api_admin_decide_refund(uuid, boolean, numeric, text),
  public.api_admin_pending_refunds(),
  public.api_my_wallet()
from public, anon;

grant execute on function
  public.api_set_payout_account(text, text, text),
  public.api_admin_verify_payout_account(uuid, boolean, text),
  public.api_admin_payout_accounts(text),
  public.api_request_provider_withdrawal(numeric),
  public.api_my_provider_wallet(),
  public.api_submit_payment(uuid, text, text, text),
  public.api_pay_from_wallet(uuid, text),
  public.api_request_withdrawal(numeric, text, text),
  public.api_admin_decide_withdrawal(uuid, boolean, text),
  public.api_admin_withdrawals(text),
  public.api_admin_decide_refund(uuid, boolean, numeric, text),
  public.api_admin_pending_refunds(),
  public.api_my_wallet()
to authenticated;

notify pgrst, 'reload schema';
commit;
