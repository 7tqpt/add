-- حدُّ محاولات التحقّق — الجزء ٣ من ٣: المحو. يُلصق وحدَه ثمّ الذي يليه.
-- آمنٌ عند التكرار. **وآخرُ سطرٍ إيصال**: إن لم تظهر «المحو ✓» في Results
-- فاللصقُ انقطع — أعده. ونصُّه مولَّدٌ من `phone_verify_attempts.sql`،
-- و`tests/phone_verify_attempts.test.mjs` يقابل الثلاثةَ بأصلها.

begin;

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

revoke all on function public.otp_clear_attempts(uuid, text)
  from public, anon, authenticated;

commit;

select 'المحو ✓' as "تمّ";
