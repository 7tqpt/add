-- ============================================================================
--  خدمة العملاء — قناة بين مستخدم التطبيق والإدارة
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run. آمن للتكرار.
--  يُنفَّذ بعد install.sql. لا يعتمد على seed.sql ولا على apply.sql.
--
--  لماذا جدول جديد ولم تكفِ `disputes`:
--    النزاع خصومة بين طرفين على حجز بعينه، والإدارة فيه حَكَم: فيه مقدّم خدمة،
--    وحجز، ومبلغ يُردّ. أما «ما قدرت أسجّل» و«الدفع خُصم ولم يصل» و«أريد تغيير
--    رقمي» فليس فيها خصم ولا حجز — فيها مستخدم يطلب مساعدة. حشرها في النزاعات
--    يُلزمها بحجزٍ لا وجود له، ويخلط ما يُحسم بما يُخدَم.
--
--  الأطراف: العميل ومقدّم الخدمة كلاهما يفتح تذكرة من تطبيقه. الإدارة وحدها
--  تردّ من اللوحة.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- التذاكر
-- ----------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id            uuid primary key default gen_random_uuid(),
  reference     text not null unique,

  -- صاحب التذكرة. `opened_by` يحدّد من أي تطبيق فُتحت، و`provider_id` يُملأ
  -- حين تُفتح من تطبيق مقدّم الخدمة — وقد يكون للشخص نفسه حسابان.
  opened_by     text not null default 'customer'
                check (opened_by in ('customer', 'provider')),
  user_id       uuid references public.app_users (id) on delete set null,
  user_name     text not null default '',
  provider_id   uuid references public.service_providers (id) on delete set null,
  provider_name text not null default '',

  subject       text not null,
  category      text not null default 'other'
                check (category in ('account', 'payment', 'booking',
                                    'technical', 'suggestion', 'other')),
  -- حجز مرتبط إن كانت الشكوى تخصّه، وليس شرطاً.
  booking_id    uuid references public.bookings (id) on delete set null,

  status        text not null default 'open'
                check (status in ('open', 'in_progress', 'waiting_customer',
                                  'resolved', 'closed')),
  priority      text not null default 'normal'
                check (priority in ('normal', 'high', 'urgent')),

  -- المسؤول الذي أخذها على عاتقه، بالبريد كما في سجل العمليات.
  assigned_to   text not null default '',

  created_at       timestamptz not null default now(),
  last_message_at  timestamptz not null default now(),
  -- أول ردّ من الإدارة: به يُقاس زمن الاستجابة، وهو المقياس الذي يهمّ العميل.
  first_response_at timestamptz,
  resolved_at      timestamptz,

  constraint ticket_resolved_needs_timestamp
    check ((status in ('resolved', 'closed')) = (resolved_at is not null)),
  -- تذكرة بلا صاحب لا يمكن الردّ عليها ولا إشعار صاحبها.
  constraint ticket_has_owner
    check (user_id is not null or provider_id is not null)
);

create index if not exists support_tickets_status_idx
  on public.support_tickets (status, last_message_at desc);
create index if not exists support_tickets_user_idx
  on public.support_tickets (user_id, created_at desc);
create index if not exists support_tickets_provider_idx
  on public.support_tickets (provider_id, created_at desc);

-- ----------------------------------------------------------------------------
-- الرسائل
-- ----------------------------------------------------------------------------
create table if not exists public.support_messages (
  id          uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references public.support_tickets (id) on delete cascade,
  author      text not null check (author in ('customer', 'provider', 'admin')),
  author_name text not null default '',
  body        text not null check (length(btrim(body)) > 0),

  -- ملاحظة داخلية بين المسؤولين لا يراها صاحب التذكرة.
  --
  -- «هذا العميل فتح ثلاث تذاكر بالموضوع نفسه» أو «راجعنا سجل الدفع ولم نجد
  -- الخصم» كلامٌ تحتاجه الإدارة ولا يُقال للعميل. بلا هذا العمود يُكتب في مكان
  -- آخر أو لا يُكتب أصلاً. وإخفاؤه مسؤولية RLS أدناه لا مسؤولية الواجهة.
  is_internal boolean not null default false,

  created_at  timestamptz not null default now(),
  constraint internal_notes_are_admin_only
    check (not is_internal or author = 'admin')
);

create index if not exists support_messages_ticket_idx
  on public.support_messages (ticket_id, created_at);

alter table public.support_tickets  enable row level security;
alter table public.support_messages enable row level security;

-- ----------------------------------------------------------------------------
-- من يرى ماذا
-- ----------------------------------------------------------------------------

/** صاحب التذكرة: العميل الذي فتحها أو مقدّم الخدمة الذي فتحها. */
create or replace function public.owns_ticket(t public.support_tickets)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (t.user_id is not null and t.user_id = public.current_app_user())
    or (t.provider_id is not null and t.provider_id = public.current_provider()),
    false)
$$;

drop policy if exists "ticket owner reads own" on public.support_tickets;
create policy "ticket owner reads own"
on public.support_tickets for select to authenticated
using (public.owns_ticket(support_tickets) or public.is_admin());

-- الإنشاء يمرّ بدالة الـ API وحدها: هي التي تولّد الرقم المرجعي وتملأ الاسم
-- وتكتب أول رسالة. الإدراج المباشر يترك تذكرة نصف مبنيّة.
drop policy if exists "admin updates tickets" on public.support_tickets;
create policy "admin updates tickets"
on public.support_tickets for update to authenticated
using (public.can_write()) with check (public.can_write());

/**
 * الرسائل: صاحب التذكرة يقرأ ما ليس داخلياً، والمسؤول يقرأ كل شيء.
 *
 * `is_internal` مذكور في السياسة لا في الاستعلام. لو كان الإخفاء في الواجهة
 * لكفى استدعاءٌ مباشر للـ API ليقرأ العميل ملاحظات الإدارة عنه.
 */
drop policy if exists "ticket messages readable by owner" on public.support_messages;
create policy "ticket messages readable by owner"
on public.support_messages for select to authenticated
using (
  public.is_admin()
  or (
    not is_internal
    and exists (
      select 1 from public.support_tickets t
       where t.id = support_messages.ticket_id and public.owns_ticket(t)
    )
  )
);

drop policy if exists "admin writes ticket messages" on public.support_messages;
create policy "admin writes ticket messages"
on public.support_messages for insert to authenticated
with check (public.can_write() and author = 'admin');

grant select on public.support_tickets, public.support_messages to authenticated;
grant update on public.support_tickets to authenticated;
grant insert on public.support_messages to authenticated;

-- ============================================================================
--  دوال التطبيق
-- ============================================================================

/**
 * يفتح تذكرة ويكتب نصّها الأول.
 *
 * `p_as_provider` لأن الشخص قد يملك حسابين — يشتري لعرسه ويبيع خدماته — فمن
 * أي تطبيق فتح التذكرة يحدّد بمن تُربط وإلى أين يصل الإشعار.
 */
create or replace function public.api_open_ticket(
  p_subject    text,
  p_body       text,
  p_category   text default 'other',
  p_booking_id uuid default null,
  p_as_provider boolean default false
)
returns public.support_tickets
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  as_prov uuid := public.current_provider();
  ticket  public.support_tickets;
  u_name  text := '';
  p_name  text := '';
begin
  if btrim(coalesce(p_subject, '')) = '' or btrim(coalesce(p_body, '')) = '' then
    raise exception 'الموضوع ونص الرسالة مطلوبان';
  end if;

  if p_as_provider then
    if as_prov is null then
      raise exception 'لا تملك ملف مقدّم خدمة';
    end if;
    select coalesce(nullif(business_name, ''), full_name) into p_name
      from public.service_providers where id = as_prov;
  else
    if me is null then
      raise exception 'أكمل تسجيل ملفك أولاً';
    end if;
    select full_name into u_name from public.app_users where id = me;
  end if;

  -- الحجز المرتبط يجب أن يكون حجزَ صاحب التذكرة، وإلا صار الرقم وسيلة
  -- لاستكشاف حجوزات الآخرين من رسالة دعم.
  if p_booking_id is not null then
    if not exists (
      select 1 from public.bookings b
       where b.id = p_booking_id
         and ((not p_as_provider and b.user_id = me)
              or (p_as_provider and b.provider_id = as_prov))
    ) then
      raise exception 'الحجز غير موجود أو لا يخصّك';
    end if;
  end if;

  insert into public.support_tickets (
    reference, opened_by, user_id, user_name, provider_id, provider_name,
    subject, category, booking_id
  ) values (
    'SUP-' || to_char(now(), 'YYYY') || '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    case when p_as_provider then 'provider' else 'customer' end,
    case when p_as_provider then null else me end,
    coalesce(u_name, ''),
    case when p_as_provider then as_prov else null end,
    coalesce(p_name, ''),
    btrim(p_subject), p_category, p_booking_id
  ) returning * into ticket;

  insert into public.support_messages (ticket_id, author, author_name, body)
  values (ticket.id,
          case when p_as_provider then 'provider' else 'customer' end,
          coalesce(nullif(p_name, ''), u_name, ''),
          btrim(p_body));

  return ticket;
end;
$$;

/** ردّ صاحب التذكرة. يعيد فتحها إن كانت تنتظره. */
create or replace function public.api_reply_ticket(p_ticket_id uuid, p_body text)
returns public.support_messages
language plpgsql security definer set search_path = public as $$
declare
  ticket  public.support_tickets;
  message public.support_messages;
begin
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'الرسالة فارغة';
  end if;

  select * into ticket from public.support_tickets where id = p_ticket_id;
  if not found or not public.owns_ticket(ticket) then
    raise exception 'التذكرة غير موجودة أو لا تخصّك';
  end if;
  if ticket.status = 'closed' then
    raise exception 'التذكرة مغلقة — افتح تذكرة جديدة';
  end if;

  insert into public.support_messages (ticket_id, author, author_name, body)
  values (ticket.id, ticket.opened_by,
          coalesce(nullif(ticket.provider_name, ''), ticket.user_name),
          btrim(p_body))
  returning * into message;

  update public.support_tickets
     set last_message_at = now(),
         -- ردّ صاحب التذكرة يعيدها إلى طاولة الإدارة.
         status = case when status in ('waiting_customer', 'resolved') then 'open'
                       else status end,
         resolved_at = case when status in ('waiting_customer', 'resolved')
                            then null else resolved_at end
   where id = ticket.id;

  return message;
end;
$$;

/** إغلاق صاحب التذكرة لتذكرته — «انحلّت، شكراً». */
create or replace function public.api_close_ticket(p_ticket_id uuid)
returns public.support_tickets
language plpgsql security definer set search_path = public as $$
declare
  ticket public.support_tickets;
begin
  select * into ticket from public.support_tickets where id = p_ticket_id;
  if not found or not public.owns_ticket(ticket) then
    raise exception 'التذكرة غير موجودة أو لا تخصّك';
  end if;

  update public.support_tickets
     set status = 'closed', resolved_at = coalesce(resolved_at, now())
   where id = ticket.id
  returning * into ticket;

  return ticket;
end;
$$;

revoke all on function public.api_open_ticket(text, text, text, uuid, boolean) from public;
revoke all on function public.api_reply_ticket(uuid, text) from public;
revoke all on function public.api_close_ticket(uuid) from public;
grant execute on function public.api_open_ticket(text, text, text, uuid, boolean) to authenticated;
grant execute on function public.api_reply_ticket(uuid, text) to authenticated;
grant execute on function public.api_close_ticket(uuid) to authenticated;

-- ============================================================================
--  ردّ الإدارة — يُستدعى من اللوحة
-- ============================================================================

/**
 * يضيف رسالة من الإدارة، ويحدّث حالة التذكرة، ويُشعر صاحبها.
 *
 * الثلاثة في دالة واحدة لأن تركها للواجهة يعني أن انقطاعاً في المنتصف يترك
 * رسالةً بلا إشعار — يردّ المسؤول ولا يعلم العميل. والملاحظة الداخلية لا
 * تُشعر أحداً ولا تحرّك الحالة: هي كلام الإدارة مع نفسها.
 */
create or replace function public.admin_reply_ticket(
  p_ticket_id  uuid,
  p_body       text,
  p_internal   boolean default false,
  p_new_status text default null
)
returns public.support_messages
language plpgsql security definer set search_path = public as $$
declare
  ticket  public.support_tickets;
  message public.support_messages;
  actor   text := coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), 'الإدارة');
begin
  if not public.can_write() then
    raise exception 'لا تملك صلاحية الرد';
  end if;
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'الرسالة فارغة';
  end if;

  select * into ticket from public.support_tickets where id = p_ticket_id;
  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  insert into public.support_messages (ticket_id, author, author_name, body, is_internal)
  values (ticket.id, 'admin', actor, btrim(p_body), coalesce(p_internal, false))
  returning * into message;

  if coalesce(p_internal, false) then
    return message;
  end if;

  update public.support_tickets
     set last_message_at   = now(),
         first_response_at = coalesce(first_response_at, now()),
         status = coalesce(nullif(p_new_status, ''), 'waiting_customer'),
         resolved_at = case
           when coalesce(nullif(p_new_status, ''), 'waiting_customer')
                in ('resolved', 'closed') then coalesce(resolved_at, now())
           else null
         end
   where id = ticket.id;

  insert into public.notifications (user_id, provider_id, kind, title, body, data)
  values (
    ticket.user_id, ticket.provider_id, 'message',
    'ردّ من خدمة العملاء',
    left(btrim(p_body), 140),
    jsonb_build_object('ticket_id', ticket.id, 'reference', ticket.reference)
  );

  return message;
end;
$$;

revoke all on function public.admin_reply_ticket(uuid, text, boolean, text) from public;
grant execute on function public.admin_reply_ticket(uuid, text, boolean, text) to authenticated;

-- ============================================================================
--  طريقة عرض اللوحة
-- ============================================================================
drop view if exists public.v_admin_tickets;
create view public.v_admin_tickets
with (security_invoker = true) as
select
  t.*,
  coalesce(nullif(t.provider_name, ''), t.user_name) as requester_name,
  (select count(*) from public.support_messages m
    where m.ticket_id = t.id and not m.is_internal)::integer as messages_count,
  (select m.body from public.support_messages m
    where m.ticket_id = t.id and not m.is_internal
    order by m.created_at desc limit 1) as last_message,
  coalesce(b.reference, '') as booking_reference
from public.support_tickets t
left join public.bookings b on b.id = t.booking_id;

grant select on public.v_admin_tickets to authenticated;

commit;

-- ============================================================================
--  التحقق — المتوقّع: جدولان، وطريقة عرض، و ٤ دوال
-- ============================================================================
select 'الجداول' as البند, count(*)::text as القيمة
  from information_schema.tables
 where table_schema = 'public' and table_name in ('support_tickets', 'support_messages')
union all
select 'طريقة العرض', count(*)::text from pg_views
 where schemaname = 'public' and viewname = 'v_admin_tickets'
union all
select 'الدوال', count(*)::text from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('api_open_ticket', 'api_reply_ticket',
                        'api_close_ticket', 'admin_reply_ticket');
