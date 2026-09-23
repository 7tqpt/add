-- ============================================================================
--  حدُّ محاولات التحقّق — القطعةُ الجديدةُ من phone_verify.sql وحدَها
--
--  شغّله بعد install.sql. آمنٌ عند التكرار، ولا يحتاج بقيّةَ الملفّ:
--  لا يعتمد إلّا على `public.app_users`.
--
--  **ولا مصدرَ ثانياً للحقيقة**: نصُّه منسوخٌ حرفاً من القسم ٨–١٠ في
--  `phone_verify.sql`، و`tests/phone_verify_attempts.test.mjs` يقابل الملفّين
--  سطراً بسطر ويحمرّ إن افترقا. وأُخرج لأنّ لصقَ ٤٣٢ سطراً في محرّر
--  Supabase انقطع في ثلثه مرّةً، فخرج `$$` بلا غلق ورُدَّ الملفُّ كلُّه.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ٨. وحدُّ **المحاولات** — وكان الإرسالُ محدوداً والتحقّقُ مفتوحاً
--
-- **والثغرةُ كشفها فحصٌ أمنيّ.** الإرسالُ محروسٌ أعلاه حرزاً جيّداً: واحدةٌ
-- في الدقيقة وثلاثٌ في الساعة وعشرٌ في اليوم، تُحجز وتُسجَّل في عمليّةٍ
-- واحدة. **والتحقّقُ لم يكن محدوداً بشيء** — فمن ملك جلسةً ينادي `verify`
-- ألفَ مرّةٍ بألفِ رمز.
--
-- ── والمسارُ بتمامه ────────────────────────────────────────────────────────
--
--   يفتح حساباً (دقيقة)، ثمّ ينادي `send` **برقم غيره** — والرقمُ يأتي من
--   جسم الطلب لا من ملفّه — فتصل الضحيّةَ رسالةُ واتساب. ثمّ يُخمَّن الرمز.
--   وإن أصاب، رُبط رقمُ الضحيّة بحسابه هو، وصار المؤكَّدَ الذي نتواصل به.
--
-- ── والحدُّ على الرقم قبل المستخدم ────────────────────────────────────────
--
-- **حدٌّ على المستخدم وحدَه يُلتفّ عليه بحسابات**: عشرةُ حسابات تعني عشرةَ
-- أضعاف المحاولات على الرقم نفسِه. فيُعدّ على **الرقم** أوّلاً — وهو
-- المستهدَف — ثمّ على المستخدم، ليُمنع من يجرّب أرقاماً كثيرةً بحسابٍ واحد.
--
-- ── ولا رمزَ هنا ولا بصمتُه، كما في جدول الإرسال ──────────────────────────
--
-- فيه: مَن حاول، وعلى أيّ رقم، ومتى. ولو سُرّب كلُّه لم يُمكِّن أحداً من
-- تأكيد رقمٍ ليس له.
-- ----------------------------------------------------------------------------
create table if not exists public.phone_otp_attempts (
  id         bigserial primary key,
  user_id    uuid not null references public.app_users (id) on delete cascade,
  phone      text not null,
  created_at timestamptz not null default now()
);

create index if not exists phone_otp_attempts_user_time_idx
  on public.phone_otp_attempts (user_id, created_at desc);
create index if not exists phone_otp_attempts_phone_time_idx
  on public.phone_otp_attempts (phone, created_at desc);

alter table public.phone_otp_attempts enable row level security;

-- ولا سياسةَ لأحد — كنظيره أعلاه. عدّادٌ يُقرأ أو يُكتب من التطبيق يُصفَّر.

-- ----------------------------------------------------------------------------
-- ٩. حجزُ محاولة — تُنادى **قبل** سؤال المُرسِل لا بعده
--
-- **ولا «اسأل المُرسِلَ ثمّ سجّل»**: من سجّل بعد الجواب لم يسجّل شيئاً على
-- من قطع الاتّصال قبل أن يصله الجواب — فيُعاد الطلبُ بلا حساب. فتُحجز
-- المحاولةُ أوّلاً، ومن لم يُسمح له لم تُسجَّل عليه.
--
-- والحدود: خمسٌ في ربع ساعةٍ وعشرون في اليوم. ومن يكتب رمزاً وصله يخطئ
-- مرّةً أو مرّتين، والخمسُ سعةٌ له. ومن يخمّن يحتاج آلافاً.
-- ----------------------------------------------------------------------------
create or replace function public.otp_claim_verify(
  p_auth_user uuid,
  p_phone     text
)
returns table (allowed boolean, reason text, wait_seconds integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user       uuid;
  v_phone_15m  integer;
  v_phone_day  integer;
  v_user_15m   integer;
  v_user_day   integer;
  v_oldest     timestamptz;
begin
  select id into v_user from public.app_users where auth_user_id = p_auth_user;

  if v_user is null then
    return query select false, 'no_profile', 0;
    return;
  end if;

  if coalesce(trim(p_phone), '') = '' then
    return query select false, 'no_phone', 0;
    return;
  end if;

  -- ── على الرقم: وهو المستهدَف، فيُعدّ عليه أوّلاً ─────────────────────────
  select count(*), min(created_at) into v_phone_15m, v_oldest
    from public.phone_otp_attempts
   where phone = p_phone and created_at > now() - interval '15 minutes';

  if v_phone_15m >= 5 then
    return query
      select false,
             'attempt_limit',
             greatest(1, ceil(extract(epoch from
               (v_oldest + interval '15 minutes' - now())))::integer);
    return;
  end if;

  select count(*) into v_phone_day
    from public.phone_otp_attempts
   where phone = p_phone and created_at > now() - interval '24 hours';

  if v_phone_day >= 20 then
    return query select false, 'attempt_day_limit', 0;
    return;
  end if;

  -- ── وعلى صاحب الجلسة: يمنع من يجرّب أرقاماً كثيرةً بحسابٍ واحد ──────────
  select count(*), min(created_at) into v_user_15m, v_oldest
    from public.phone_otp_attempts
   where user_id = v_user and created_at > now() - interval '15 minutes';

  if v_user_15m >= 5 then
    return query
      select false,
             'attempt_limit',
             greatest(1, ceil(extract(epoch from
               (v_oldest + interval '15 minutes' - now())))::integer);
    return;
  end if;

  select count(*) into v_user_day
    from public.phone_otp_attempts
   where user_id = v_user and created_at > now() - interval '24 hours';

  if v_user_day >= 20 then
    return query select false, 'attempt_day_limit', 0;
    return;
  end if;

  insert into public.phone_otp_attempts (user_id, phone) values (v_user, p_phone);
  return query select true, 'ok', 0;
end;
$$;

-- ----------------------------------------------------------------------------
-- ١٠. والمحاولاتُ تُمحى عند النجاح
--
-- وإلّا بقي من أكّد رقمه محسوباً عليه عشرون محاولةً ليومٍ كامل — فلو بدّل
-- رقمه في اليوم نفسِه (والتبديلُ يُبطل التأكيد، انظر ٦) وجد البابَ مغلقاً
-- بسبب محاولاتٍ كلُّها نجحت.
-- ----------------------------------------------------------------------------
create or replace function public.otp_clear_attempts(
  p_auth_user uuid,
  p_phone     text
)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.phone_otp_attempts
   where phone = p_phone
      or user_id = (select id from public.app_users where auth_user_id = p_auth_user)
$$;

revoke all on function public.otp_claim_verify(uuid, text)
  from public, anon, authenticated;
revoke all on function public.otp_clear_attempts(uuid, text)
  from public, anon, authenticated;

commit;
