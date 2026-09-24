-- حدُّ محاولات التحقّق — الجزء ٢ من ٣: الحدّ. يُلصق وحدَه ثمّ الذي يليه.
-- آمنٌ عند التكرار. **وآخرُ سطرٍ إيصال**: إن لم تظهر «الحدّ ✓» في Results
-- فاللصقُ انقطع — أعده. ونصُّه مولَّدٌ من `phone_verify_attempts.sql`،
-- و`tests/phone_verify_attempts.test.mjs` يقابل الثلاثةَ بأصلها.

begin;

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

revoke all on function public.otp_claim_verify(uuid, text)
  from public, anon, authenticated;

commit;

select 'الحدّ ✓' as "تمّ";
