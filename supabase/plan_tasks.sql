-- ============================================================================
--  مهامّ خطة العرس: قائمةٌ تُشطب، لا حقولٌ تُملأ
--
--  شغّله في أي وقت. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** «خطة العرس» كانت أربعة أرقام — تاريخٌ وميزانيةٌ وعددُ
--  ضيوفٍ ومحافظة — تُملأ مرّةً ثم لا يعود إليها أحد. والعرس ليس أربعة أرقام،
--  هو ثلاثون شيئاً يجب أن يُفعل قبل يومٍ بعينه: البطاقات تُطبع، والفستان
--  يُفصَّل، والمهر يُسلَّم، والقاعة تُعايَن. ومن لا يجد قائمةً يكتبها في ورقةٍ
--  تضيع أو في مذكّرة جواله — فيخرج تجهيزُ العرس من المنصّة، ويبقى فيها الحجزُ
--  وحده.
--
--  **والتقدّم يُحسب من المشطوب لا يُكتب:** نسبةٌ يكتبها المستخدم بنفسه لا
--  تعني شيئاً. وهي التي تعرضها الشاشة رقماً واحداً فوق الشريط.
--
--  **وقائمةٌ افتراضية تُزرع مع الخطّة:** شاشةٌ فارغة تطلب من العروسين أن
--  يتذكّروا ثلاثين مهمّةً بأنفسهم هي ورقةٌ بيضاء بأزرار. فتُزرع قائمةٌ يمنيّةٌ
--  معقولة تُحذف منها وتُزاد عليها.
-- ============================================================================

begin;

create table if not exists public.plan_tasks (
  id         uuid primary key default gen_random_uuid(),
  plan_id    uuid not null references public.wedding_plans (id) on delete cascade,
  title      text not null check (length(btrim(title)) between 1 and 160),
  is_done    boolean not null default false,
  due_date   date,
  sort_order integer not null default 0,
  -- **متى شُطبت لا أنها شُطبت فقط:** «أُنجزت» بلا وقتٍ لا تُرتَّب ولا تُراجَع.
  done_at    timestamptz,
  created_at timestamptz not null default now(),

  -- حالةٌ وزمنُها لا يفترقان: صفٌّ «منجَز» بلا وقت، أو «غير منجَز» بوقتٍ،
  -- كلاهما كذبٌ صامتٌ يتسرّب من تحديثٍ ناقص.
  constraint plan_task_done_time check (is_done = (done_at is not null))
);

create index if not exists plan_tasks_plan_idx
  on public.plan_tasks (plan_id, sort_order, created_at);

comment on table public.plan_tasks is
  'مهامّ تجهيز العرس. صاحبُ الخطّة وحده يراها ويكتبها.';

alter table public.plan_tasks enable row level security;

-- المهمّة تتبع خطّتها: من يملك الخطّة يملكها. ومقدّمُ الخدمة لا يرى شيئاً —
-- كما لا يرى الخطّة نفسها.
drop policy if exists plan_tasks_owner on public.plan_tasks;
create policy plan_tasks_owner on public.plan_tasks
  for all to authenticated
  using (
    exists (
      select 1 from public.wedding_plans w
       where w.id = plan_tasks.plan_id and w.user_id = public.current_app_user()
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.wedding_plans w
       where w.id = plan_tasks.plan_id and w.user_id = public.current_app_user()
    )
    or public.can_write()
  );

grant select, insert, update, delete on public.plan_tasks to authenticated;

-- ----------------------------------------------------------------------------
-- القائمة الافتراضية
--
-- تُزرع مرّةً واحدة لكل خطّة — والحارس هو الفحص لا حسنُ الظنّ: نداءٌ ثانٍ
-- يُضاعف القائمة، ومن حذف مهمّةً ثم فُتحت الشاشة يجدها عادت.
-- ----------------------------------------------------------------------------
create or replace function public.seed_plan_tasks(p_plan_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  if exists (select 1 from public.plan_tasks where plan_id = p_plan_id) then
    return 0;
  end if;

  -- الترتيب زمنيٌّ لا أبجديّ: ما يُفعل أوّلاً أوّلاً. والمهرُ والقاعة قبل
  -- البطاقات، لأن بطاقةً تُطبع بتاريخٍ لم تُحجز له قاعةٌ تُطبع مرّتين.
  insert into public.plan_tasks (plan_id, title, sort_order)
  select p_plan_id, t.title, t.ord
    from (values
      ('تحديد موعد العرس والاتفاق عليه بين الأهل', 10),
      ('حجز القاعة ومعاينتها', 20),
      ('الاتفاق على المهر وتسليمه', 30),
      ('عقد القران وتوثيقه', 40),
      ('حجز المصوّر والفيديو', 50),
      ('حجز الفرقة أو الفنان', 60),
      ('الاتفاق على الطعام وتجربته قبل الحجز', 70),
      ('حجز الكوشة والتنسيق', 80),
      ('فستان العروس وتفصيله', 90),
      ('بدلة العريس', 100),
      ('الذهب والمجوهرات', 110),
      ('الكوافير والتجميل', 120),
      ('حجز سيارة الزفّة', 130),
      ('طباعة بطاقات الدعوة', 140),
      ('حصر قائمة الضيوف وتوزيع الدعوات', 150),
      ('حجز شهر العسل أو الرحلة', 160),
      ('تجهيز بيت الزوجية', 170),
      ('الحلويات والكيك', 180),
      ('توزيعات الضيوف', 190),
      ('مراجعة المدفوعات والمتبقّي قبل الموعد بأسبوع', 200)
    ) as t(title, ord);

  get diagnostics n = row_count;
  return n;
end $$;

-- الزرعُ مع الخطّة نفسها: لو تُرك للتطبيق لبقيت خططُ من دخل من الويب — أو من
-- نسخةٍ أقدم — بلا قائمةٍ إلى الأبد.
create or replace function public.plan_seed_tasks() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_plan_tasks(new.id);
  return new;
end $$;

drop trigger if exists plan_tasks_seed on public.wedding_plans;
create trigger plan_tasks_seed after insert on public.wedding_plans
  for each row execute function public.plan_seed_tasks();

-- ----------------------------------------------------------------------------
-- الشطب
--
-- دالّةٌ لا `update` مباشر: `done_at` يجب أن يوافق `is_done` وإلّا رفض القيد
-- الصفَّ برسالة قاعدةٍ لا يفهمها أحد. والقاعدةُ تختم الوقت لا الجوال —
-- ساعةُ الجهاز تُضبط باليد.
-- ----------------------------------------------------------------------------
create or replace function public.api_toggle_plan_task(p_task_id uuid)
returns public.plan_tasks
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  task public.plan_tasks;
begin
  select t.* into task
    from public.plan_tasks t
    join public.wedding_plans w on w.id = t.plan_id
   where t.id = p_task_id and w.user_id = me;

  if task.id is null then
    raise exception 'المهمّة غير موجودة';
  end if;

  update public.plan_tasks
     set is_done = not is_done,
         done_at = case when is_done then null else now() end
   where id = p_task_id
  returning * into task;

  return task;
end $$;

create or replace function public.api_add_plan_task(
  p_plan_id uuid, p_title text, p_due date default null)
returns public.plan_tasks
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  task public.plan_tasks;
  next integer;
begin
  if not exists (
    select 1 from public.wedding_plans w where w.id = p_plan_id and w.user_id = me
  ) then
    raise exception 'خطة العرس غير موجودة';
  end if;

  if length(btrim(coalesce(p_title, ''))) = 0 then
    raise exception 'اكتب المهمّة أوّلاً';
  end if;

  -- في آخر القائمة لا في أوّلها: المضافُ يدوياً استدراكٌ على المزروع.
  select coalesce(max(sort_order), 0) + 10 into next
    from public.plan_tasks where plan_id = p_plan_id;

  insert into public.plan_tasks (plan_id, title, due_date, sort_order)
       values (p_plan_id, btrim(p_title), p_due, next)
  returning * into task;

  return task;
end $$;

create or replace function public.api_delete_plan_task(p_task_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.current_app_user();
  n  integer;
begin
  delete from public.plan_tasks t
   using public.wedding_plans w
   where t.id = p_task_id and w.id = t.plan_id and w.user_id = me;
  get diagnostics n = row_count;
  return n > 0;
end $$;

-- ----------------------------------------------------------------------------
-- تقدّمُ الخطّة
--
-- **العدّ في القاعدة لا في الجوال:** الشاشة تعرض «١٢ مهمّة متبقية» و«٦٠٪»،
-- ولو حُسبا في التطبيق لَلَزِم جلبُ المهامّ كلِّها لكل خطّة في القائمة.
--
-- **وطريقةٌ مستقلّة لا توسيعٌ لـ`v_plan_summary`:** تلك يُعيد `apply.sql`
-- إنشاءها بـ`drop` ثم `create`، وطريقةٌ تعتمد عليها تجعل ذلك الإسقاط يفشل —
-- فيسقط تشغيلُ `apply.sql` كلُّه على من رتّب الملفّين هكذا. وهذه لا تمسّها:
-- تقرأ الجداول مباشرةً.
-- ----------------------------------------------------------------------------
drop view if exists public.v_plan_progress;
create view public.v_plan_progress
with (security_invoker = true) as
select w.id                                       as plan_id,
       coalesce(t.total, 0)                       as tasks_total,
       coalesce(t.done, 0)                        as tasks_done,
       coalesce(t.total, 0) - coalesce(t.done, 0) as tasks_left,
       case when coalesce(t.total, 0) = 0 then 0
            else round(100.0 * t.done / t.total) end as tasks_percent,
       -- المواعيد القادمة: حجوزاتُ هذه الخطّة التي لم يمضِ يومُها ولم تُلغَ.
       coalesce(b.upcoming, 0)                    as upcoming_bookings
  from public.wedding_plans w
  left join (
    select plan_id, count(*) as total, count(*) filter (where is_done) as done
      from public.plan_tasks group by plan_id
  ) t on t.plan_id = w.id
  left join (
    select plan_id, count(*) as upcoming
      from public.bookings
     where plan_id is not null
       and event_date >= current_date
       and status in ('pending_provider', 'confirmed')
     group by plan_id
  ) b on b.plan_id = w.id;

grant select on public.v_plan_progress to authenticated;

revoke all on function public.seed_plan_tasks(uuid) from anon, authenticated;
grant execute on function public.api_toggle_plan_task(uuid) to authenticated;
grant execute on function public.api_add_plan_task(uuid, text, date) to authenticated;
grant execute on function public.api_delete_plan_task(uuid) to authenticated;

commit;

-- خططٌ أُنشئت قبل هذا الملف لا مهامّ لها: تُزرع مرّةً واحدة الآن.
do $$
declare
  p record;
  n integer := 0;
begin
  for p in select id from public.wedding_plans loop
    n := n + public.seed_plan_tasks(p.id);
  end loop;
  raise notice 'زُرعت % مهمّة في الخطط القائمة.', n;
end $$;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'الجدول' as البند,
       case when to_regclass('public.plan_tasks') is not null then '✅' else '❌' end as الحال
union all
select 'حارسُ الصفوف',
       case when exists (select 1 from pg_policies
                          where tablename = 'plan_tasks' and policyname = 'plan_tasks_owner')
       then '✅' else '❌' end
union all
select 'الزرعُ مع الخطّة',
       case when exists (select 1 from pg_trigger where tgname = 'plan_tasks_seed')
       then '✅' else '❌' end
union all
select 'خططٌ بلا مهامّ',
       case when exists (
         select 1 from public.wedding_plans w
          where not exists (select 1 from public.plan_tasks t where t.plan_id = w.id))
       then '❌ بقيت خططٌ فارغة' else '✅ لا واحدة' end;
