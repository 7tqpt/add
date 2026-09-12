-- ============================================================================
--  تحقّقُ رقم الجوال — رمزٌ على واتساب، مرّةً واحدةً في عمر الحساب
--
--  شغّله **بعد `schema.sql`** و`profile_extras.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  قرّر صاحبُ المنصّة: **من لم يؤكّد رقمه لا يرى التطبيق**. والرقمُ يُكتب في
--  «أكمل ملفك» ثمّ يُستعمل في كلّ حجزٍ للتواصل — ورقمٌ مكتوبٌ بالخطأ يعني
--  حجزاً لا يُوصَل إلى صاحبه.
--
--  ── والرمزُ لا يُخزَّن هنا ولا بصمتُه ────────────────────────────────────────
--
--  المُرسِل (Authentica) **يُنشئ الرمزَ ويتحقّق منه بنفسه**: نطلب الإرسال
--  فيرسل، ونسأله «أهذا الرمزُ لهذا الرقم؟» فيجيب. فلا جدولَ رموزٍ عندنا ولا
--  مهلةَ صلاحيّةٍ نحرسها ولا عدَّ محاولاتٍ خاطئة — وكلُّ ذلك عندهم.
--
--  وهذا **أحرزُ** لا أقلَّ: رمزٌ لا يُخزَّن لا يُسرَّب من قاعدتنا.
--
--  ── وما يُخزَّن: أثرُ الإرسال، لأنّ كلَّ رسالةٍ تُنقِص رصيداً ────────────────
--
--  كلُّ رسالةِ واتساب تُخصم من رصيد صاحب المنصّة. فمن ضغط «أعد الإرسال»
--  عشرين مرّةً أنقصه عشرين، ومن كتب حلقةً آليّةً أفرغ الرصيدَ في دقائق —
--  فتتوقّف المنصّةُ عن تسجيل أيّ مستخدمٍ جديد.
--
--  **والحدُّ في الخادم لا في الشاشة:** مهلةُ الشاشة زينةٌ تُتجاوز بنداءٍ
--  مباشرٍ إلى الدالّة. فيُسجَّل كلُّ إرسالٍ في `phone_otp_sends`، وتُمنع
--  الزيادةُ عليه من القاعدة نفسِها.
--
--  ── والحاجزُ بمفتاحٍ يُقلَب، ولم يُقلَب بعد ─────────────────────────────────
--
--  `require_phone_verification` يبدأ **مطفأً**. وليس هذا تراجعاً عن قرار
--  صاحب المنصّة: هو مفتاحُ أمانٍ لا يُقلَب إلّا بعد أن يثبت شيئان — أنّ
--  مفتاح المُرسِل موضوعٌ في أسرار الدوالّ، وأنّ واتساب **يصل فعلاً** إلى رقمٍ
--  يمنيّ. ولو شُغّل قبلهما لَحُبس صاحبُ المنصّة نفسُه خارج تطبيقه، ومعه كلُّ
--  مستخدمٍ قائم، ولا بابَ يُفتح إلّا بيدٍ في القاعدة.
--
--  ويُقلَب بسطر:
--    update public.app_settings set require_phone_verification = true where id = 1;
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. متى أُكّد الرقم — ووقتٌ لا رايةٌ
--
-- `boolean` يقول «أُكّد» ولا يقول «متى». والوقتُ يُسأل عنه فعلاً: من شكا أنّ
-- حجزه لم يصله أحدٌ يُنظر في رقمه ومتى ثبت، ومن بدّل رقمَه يُعرف أيُّهما
-- المؤكَّد.
-- ----------------------------------------------------------------------------
alter table public.app_users
  add column if not exists phone_verified_at timestamptz;

comment on column public.app_users.phone_verified_at is
  'لحظةُ تأكيد الرقم برمز واتساب. فراغٌ = لم يُؤكَّد بعد.';

-- ----------------------------------------------------------------------------
-- ٢. مفتاحُ الحاجز
-- ----------------------------------------------------------------------------
alter table public.app_settings
  add column if not exists require_phone_verification boolean not null default false;

comment on column public.app_settings.require_phone_verification is
  'حين يصير true لا يرى التطبيقَ من لم يؤكّد رقمه. يُقلَب بعد التأكّد من وصول واتساب.';

-- ----------------------------------------------------------------------------
-- ٣. أثرُ الإرسال — للحدّ لا للسجلّ
--
-- **ولا رمزَ في هذا الجدول.** فيه: مَن طلب، وإلى أيّ رقم، ومتى. ولو سُرّب
-- كلُّه لم يُمكِّن أحداً من تأكيد رقمٍ ليس له.
-- ----------------------------------------------------------------------------
create table if not exists public.phone_otp_sends (
  id         bigserial primary key,
  user_id    uuid not null references public.app_users (id) on delete cascade,
  phone      text not null,
  created_at timestamptz not null default now()
);

create index if not exists phone_otp_sends_user_time_idx
  on public.phone_otp_sends (user_id, created_at desc);

alter table public.phone_otp_sends enable row level security;

-- **ولا سياسةَ لأحد.** جدولٌ مفعَّلُ الحرزِ بلا سياسةٍ ممنوعٌ على الجميع —
-- ولا يلمسه إلّا مفتاحُ الخدمة من داخل دالّة الحدّ. وهذا مقصود: عدّادُ
-- الحدّ لو قُرئ أو كُتب من التطبيق لَأمكن تصفيرُه.

-- ----------------------------------------------------------------------------
-- ٤. حدُّ الإرسال — يُطالَب به ويُسجَّل في عمليّةٍ واحدة
--
-- **ولا «اسأل ثمّ أرسل».** بين سؤالٍ عن الرصيد وإرسالٍ بعده فرجةٌ يمرّ منها
-- نداءان متزامنان فيُرسلان معاً. فالدالّةُ **تحجز** الإرسالَ وتسجّله في
-- الوقت نفسِه، ومن لم تسمح له لم تُسجّل عليه شيئاً.
--
-- والحدود: واحدةٌ كلَّ دقيقة، وثلاثٌ في الساعة، وعشرٌ في اليوم. وهي حدودُ
-- **مستخدمٍ واحد**، وطلبُ التأكيد لا يقع إلّا من حسابٍ مفتوحٍ بالبريد —
-- فالبابُ مغلقٌ على الغرباء أصلاً.
-- ----------------------------------------------------------------------------
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
   where auth_user_id = p_auth_user;

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

-- ----------------------------------------------------------------------------
-- ٥. إثباتُ التأكيد
--
-- تُنادى **بعد** أن يقول المُرسِلُ `verified: true`. وتكتب الرقمَ كما أُكّد:
-- من كتب رقماً في ملفّه ثمّ أكّد غيرَه يبقى المؤكَّدُ هو ما نتواصل به.
--
-- **ولا تُكتب مرّتين:** `phone_verified_at` لا يُبدَّل إن كان موضوعاً، فلا
-- يُزحف تاريخُ التأكيد الأوّل بنداءٍ لاحق.
-- ----------------------------------------------------------------------------
create or replace function public.otp_mark_verified(
  p_auth_user uuid,
  p_phone     text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
begin
  select id into v_user from public.app_users where auth_user_id = p_auth_user;
  if v_user is null then
    return false;
  end if;

  update public.app_users
     set phone             = p_phone,
         phone_verified_at = coalesce(phone_verified_at, now())
   where id = v_user;

  return true;
end;
$$;

-- ----------------------------------------------------------------------------
-- ٦. الصلاحيات — للخدمة وحدها
--
-- **وهذا هو موضعُ الخطر كلِّه.** لو مُنحت `otp_mark_verified` للمسجَّلين
-- لَأكّد كلُّ مستخدمٍ رقمَ من شاء بنداءٍ واحدٍ بلا رمز — فيصير الحاجزُ زينةً.
-- ولو مُنحت `otp_claim_send` لَأمكن استنزافُ الرصيد بحلقةٍ لا تُرسل شيئاً.
--
-- فتُنتزع الصلاحيةُ من الجميع صراحةً: `security definer` يعمل بصلاحية
-- كاتبه، والافتراضُ في Postgres أنّ `public` تنفّذ الدوالّ.
-- ----------------------------------------------------------------------------
revoke all on function public.otp_claim_send(uuid, text)
  from public, anon, authenticated;
revoke all on function public.otp_mark_verified(uuid, text)
  from public, anon, authenticated;

commit;
