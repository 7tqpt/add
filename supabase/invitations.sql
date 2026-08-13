-- ============================================================================
--  دعوات الموظفين — إضافة من داخل اللوحة
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run. آمن للتكرار.
--  يُنفَّذ بعد roles.sql.
--
--  المشكلة:
--    إنشاء حساب مصادقة يحتاج مفتاح `service_role`، وهو مفتاح يتجاوز RLS كلها.
--    وضعُه في اللوحة يعني تسليمه لكل من يفتح صفحتها — فلا سبيل إلى «أنشئ
--    الحساب من اللوحة» مباشرةً بلا خادم وسيط.
--
--  الحل: الدعوة.
--    المالك ينشئ دعوةً من اللوحة فيها البريد والدور، فيخرج له **رمز**. يسلّمه
--    للموظف بأي وسيلة. والموظف يفتح صفحة الدخول، ويسجّل نفسه ببريده وكلمة مرور
--    يختارها هو، ويلصق الرمز — فيُمنح الدور فوراً.
--
--  وهذا أسلم من إنشاء الحساب نيابةً عنه لا أضعف: كلمة مرور الموظف لا يعرفها
--  المالك، ولا تمرّ في رسالة واتساب، ولا تبقى في ذهن أحد.
--
--  شرطان لقبول الدعوة معاً، لا أحدهما:
--    ١. الرمز صحيح وغير منتهٍ وغير مستعمل.
--    ٢. بريد الحساب الذي يقبلها **هو** البريد المدعوّ.
--  فمن سرّب إليه الرمز لا ينفعه، ومن عرف البريد وحده لا يكفيه.
-- ============================================================================

begin;

create table if not exists public.admin_invitations (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  role        text not null check (role in ('owner', 'manager', 'operations',
                                            'finance', 'support', 'moderator', 'viewer')),
  -- رمزٌ عشوائي يُسلَّم باليد. قصير ليُقرأ في رسالة، وعشوائيته كافية لأنه
  -- ينتهي بعد أيام ويُقبل مرةً واحدة ومع البريد الصحيح وحده.
  token       text not null unique,
  invited_by  text not null default '',
  note        text not null default '',
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,

  constraint invitation_accepted_has_user
    check ((accepted_at is null) = (accepted_by is null))
);

create index if not exists admin_invitations_email_idx
  on public.admin_invitations (lower(email)) where accepted_at is null;

alter table public.admin_invitations enable row level security;

-- ----------------------------------------------------------------------------
-- من يرى الدعوات
--
--  المالك وحده. والرمز نفسه لا يُقرأ إلا منه — لأن من قرأ رمزاً مدعوّاً بدور
--  «مالك» وأمكنه إنشاء بريد مطابق صار مالكاً.
-- ----------------------------------------------------------------------------
drop policy if exists invitations_owner_read on public.admin_invitations;
create policy invitations_owner_read on public.admin_invitations
  for select to authenticated using (public.can_write_area('admins'));

drop policy if exists invitations_owner_writes on public.admin_invitations;
create policy invitations_owner_writes on public.admin_invitations
  for all to authenticated
  using (public.can_write_area('admins')) with check (public.can_write_area('admins'));

grant select, insert, update, delete on public.admin_invitations to authenticated;

-- ----------------------------------------------------------------------------
-- إنشاء الدعوة — للمالك
-- ----------------------------------------------------------------------------
create or replace function public.api_invite_admin(
  p_email text,
  p_role  text,
  p_note  text default ''
)
returns public.admin_invitations
language plpgsql security definer set search_path = public as $$
declare
  invitation public.admin_invitations;
  clean_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not public.can_write_area('admins') then
    raise exception 'إضافة المسؤولين للمالك وحده';
  end if;
  if clean_email = '' or clean_email not like '%_@_%.__%' then
    raise exception 'البريد غير صالح';
  end if;
  if p_role is null or p_role not in ('owner', 'manager', 'operations',
                                      'finance', 'support', 'moderator', 'viewer') then
    raise exception 'الدور غير معروف';
  end if;

  if exists (select 1 from public.admins a where lower(a.email) = clean_email) then
    raise exception 'هذا البريد مسؤول بالفعل';
  end if;

  -- دعوةٌ معلّقة لنفس البريد تُستبدل: إبقاء رمزين صالحين لبريد واحد يوسّع
  -- سطح الخطأ بلا فائدة.
  delete from public.admin_invitations
   where lower(email) = clean_email and accepted_at is null;

  insert into public.admin_invitations (email, role, token, invited_by, note)
  values (
    clean_email,
    p_role,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
    coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''),
    coalesce(p_note, '')
  )
  returning * into invitation;

  return invitation;
end;
$$;

-- ----------------------------------------------------------------------------
-- قبول الدعوة — يستدعيها الموظف بعد أن يسجّل حسابه
-- ----------------------------------------------------------------------------
create or replace function public.api_accept_invitation(p_token text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  invitation public.admin_invitations;
  me    uuid := auth.uid();
  mail  text := lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''));
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;

  select * into invitation
    from public.admin_invitations
   where token = upper(btrim(coalesce(p_token, '')));

  -- رسالةٌ واحدة لكل أسباب الرفض عمداً: التمييز بين «رمز خاطئ» و«رمز صحيح
  -- لبريد آخر» يحوّل النموذج إلى أداة تخمين.
  if not found
     or invitation.accepted_at is not null
     or invitation.expires_at < now()
     or lower(invitation.email) <> mail
  then
    raise exception 'الدعوة غير صالحة — تأكّد من الرمز ومن أنك سجّلت بالبريد المدعوّ';
  end if;

  if exists (select 1 from public.admins a where a.user_id = me) then
    raise exception 'حسابك مسؤول بالفعل';
  end if;

  insert into public.admins (user_id, email, role)
  values (me, invitation.email, invitation.role);

  update public.admin_invitations
     set accepted_at = now(), accepted_by = me
   where id = invitation.id;

  return invitation.role;
end;
$$;

revoke all on function public.api_invite_admin(text, text, text) from public;
revoke all on function public.api_accept_invitation(text) from public;
grant execute on function public.api_invite_admin(text, text, text) to authenticated;
grant execute on function public.api_accept_invitation(text) to authenticated;

-- طريقة عرض بلا الرمز، لقائمة الدعوات المعلّقة في اللوحة.
drop view if exists public.v_admin_invitations;
create view public.v_admin_invitations
with (security_invoker = true) as
select
  i.id, i.email, i.role, i.token, i.invited_by, i.note,
  i.created_at, i.expires_at, i.accepted_at,
  case
    when i.accepted_at is not null then 'accepted'
    when i.expires_at < now() then 'expired'
    else 'pending'
  end as status
from public.admin_invitations i;

grant select on public.v_admin_invitations to authenticated;

commit;

-- ============================================================================
--  التحقق
-- ============================================================================
select 'جدول الدعوات' as البند,
       count(*)::text as القيمة
  from information_schema.tables
 where table_schema = 'public' and table_name = 'admin_invitations'
union all
select 'دوال الدعوة',
       count(*)::text from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('api_invite_admin', 'api_accept_invitation')
union all
select 'دعوات معلّقة',
       count(*)::text from public.admin_invitations where accepted_at is null;
