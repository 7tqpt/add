-- حدُّ محاولات التحقّق — الجزء ١ من ٣: الجدول. يُلصق وحدَه ثمّ الذي يليه.
-- آمنٌ عند التكرار. **وآخرُ سطرٍ إيصال**: إن لم تظهر «الجدول ✓» في Results
-- فاللصقُ انقطع — أعده. ونصُّه مولَّدٌ من `phone_verify_attempts.sql`،
-- و`tests/phone_verify_attempts.test.mjs` يقابل الثلاثةَ بأصلها.

begin;

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

commit;

select 'الجدول ✓' as "تمّ";
