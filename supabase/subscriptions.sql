-- ============================================================================
--  الاشتراكات: المزوّد يشترك من التطبيق، والمنصّة تحصّل
--
--  شغّله بعد `payments_app.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** الباقات معروضةٌ في اللوحة، و`provider_subscriptions`
--  جدولٌ كامل بسياساته — **ولا أحد يكتب فيه** إلّا بيانات العرض. فلا سبيل
--  لمزوّدٍ أن يشترك، ولا دخلَ للمنصّة منهم أصلاً. عمولةُ الحجز وحدها لا تكفي
--  في سوقٍ أوّلُ حجزٍ فيه يأتي بعد أسابيع من التسجيل.
--
--  **والطريق هو طريق الدفع نفسه لا طريقٌ ثانٍ:** المزوّد يحوّل ويُبلغ، فتصل
--  حوالتُه صفحةَ المدفوعات في اللوحة مع حوالات العملاء، وتؤكّدها الإدارة
--  بالزرّ نفسه. و`payments.kind` فيها `subscription` منذ أوّل مخطّط.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. حالةٌ ناقصة: اشتراكٌ طُلب ولم يُدفع بعد
--
--  القيد الأصلي ثلاث حالات — نشط، منتهٍ، ملغى — ولا رابعة لِما بين الطلب
--  والتأكيد. وبلا حالةٍ للانتظار يُختار أحد سيّئين: يُنشأ نشطاً قبل وصول المال
--  (فيُشترك بلا دفع)، أو لا يُنشأ (فلا يُعرف من طلب).
-- ----------------------------------------------------------------------------
alter table public.provider_subscriptions
  drop constraint if exists provider_subscriptions_status_check;
alter table public.provider_subscriptions
  add constraint provider_subscriptions_status_check
  check (status in ('pending', 'active', 'expired', 'cancelled'));

-- والحوالةُ التي تخصّه: بها يُربط التأكيد بالتفعيل بلا تخمين.
alter table public.provider_subscriptions
  add column if not exists payment_id uuid references public.payments (id) on delete set null;

-- طلبٌ معلّق واحدٌ لكل مزوّد: ضغطتان على «اشترك» لا تُنتجان طلبين.
create unique index if not exists provider_subscriptions_one_pending
  on public.provider_subscriptions (provider_id) where status = 'pending';

-- ----------------------------------------------------------------------------
-- ٢. الاشتراك
--
--  الباقةُ المجّانية تُفعَّل فوراً — لا مالَ يُنتظر. وما له سعرٌ يُنشأ معلّقاً
--  مع حوالةٍ في `payments`، فلا يُفعَّل إلا بيدٍ ترى المال.
-- ----------------------------------------------------------------------------
create or replace function public.api_subscribe(
  p_plan_id uuid, p_method text default 'jawali', p_sender_ref text default '')
returns public.provider_subscriptions
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := public.current_provider();
  plan public.subscription_plans;
  prov public.service_providers;
  pay  public.payments;
  sub  public.provider_subscriptions;
begin
  if me is null then
    raise exception 'الاشتراك لمقدّمي الخدمة';
  end if;

  select * into plan from public.subscription_plans where id = p_plan_id;
  if not found or not plan.is_active then
    raise exception 'هذه الباقة غير متاحة';
  end if;

  if exists (select 1 from public.provider_subscriptions
              where provider_id = me and status = 'pending') then
    raise exception 'لك طلبُ اشتراكٍ قيد التأكيد';
  end if;

  select * into prov from public.service_providers where id = me;

  -- المجّانية: تُفعَّل الآن.
  if plan.price = 0 then
    insert into public.provider_subscriptions
           (provider_id, plan_id, plan_name, amount, status, starts_at, ends_at)
    values (me, plan.id, plan.name, 0, 'active', now(),
            now() + make_interval(days => plan.duration_days))
    returning * into sub;
    return sub;
  end if;

  insert into public.payments
         (reference, user_id, user_name, provider_id, provider_name, kind,
          description, amount, platform_share, net_amount, method, status, gateway_ref)
  values ('SUB-' || to_char(now(), 'YYYYMM') || '-' ||
            upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
          prov.user_id, prov.full_name, me, prov.business_name, 'subscription',
          'اشتراك: ' || plan.name, plan.price,
          -- الاشتراك دخلُ المنصّة كلُّه، لا حصّةَ فيه لأحد.
          plan.price, 0, p_method, 'pending', btrim(p_sender_ref))
  returning * into pay;

  insert into public.provider_subscriptions
         (provider_id, plan_id, plan_name, amount, status, starts_at, ends_at, payment_id)
  values (me, plan.id, plan.name, plan.price, 'pending', now(),
          now() + make_interval(days => plan.duration_days), pay.id)
  returning * into sub;

  return sub;
end $$;

comment on function public.api_subscribe(uuid, text, text) is
  'يطلب مقدّمُ الخدمة باقةً. المجّانية تُفعَّل فوراً، وما له سعرٌ ينتظر تأكيد الحوالة.';

-- ----------------------------------------------------------------------------
-- ٣. التفعيل يقع بوصول المال — مُشغِّلاً لا نداءً
--
--  **ولماذا مُشغِّل:** الحوالة تُؤكَّد من اللوحة اليوم، ومن خطّاف بوّابة دفعٍ
--  غداً، ومن محرّر SQL عند معالجة خطأ. والمُشغِّل يلزم الثلاثة، ولا يُنسى في
--  الطريق الذي يُضاف بعده.
--
--  والمدّة تُحسب من **لحظة التفعيل** لا من لحظة الطلب: من حوّل يوم الخميس
--  وأُكّدت حوالتُه يوم السبت لا يُخصم منه يومان لم ينتفع فيهما بشيء.
-- ----------------------------------------------------------------------------
create or replace function public.activate_paid_subscription()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  sub public.provider_subscriptions;
begin
  if new.kind <> 'subscription' or new.status <> 'paid'
     or old.status is not distinct from 'paid' then
    return new;
  end if;

  update public.provider_subscriptions s
     set status = 'active',
         starts_at = now(),
         ends_at = now() + make_interval(
           days => (select duration_days from public.subscription_plans
                     where id = s.plan_id))
   where s.payment_id = new.id and s.status = 'pending'
  returning * into sub;

  if sub.id is null then
    return new;
  end if;

  -- ما تمنحه الباقة يقع فعلاً: «ظهور مميز» تعني `is_featured`، وترتيبُ
  -- `v_services` و`v_providers` يقدّم المميَّزين. وبلا هذا السطر يدفع المزوّد
  -- ثمن وعدٍ لا يُنفَّذ.
  if exists (select 1 from public.subscription_plans
              where id = sub.plan_id
                and array_to_string(perks, '،') like '%ظهور مميز%') then
    update public.service_providers set is_featured = true where id = sub.provider_id;
  end if;

  perform public.notify_provider(
    sub.provider_id, 'account', 'فُعِّل اشتراكك',
    'باقة «' || sub.plan_name || '» فعّالة حتى ' ||
      to_char(sub.ends_at, 'YYYY-MM-DD') || '.',
    jsonb_build_object('subscription_id', sub.id)
  );

  return new;
end $$;

drop trigger if exists subscription_paid on public.payments;
create trigger subscription_paid
  after update of status on public.payments
  for each row execute function public.activate_paid_subscription();

-- ----------------------------------------------------------------------------
-- ٤. الانتهاء — ومعه سحبُ ما مُنح
--
--  اشتراكٌ انتهى ويبقى صاحبُه مميَّزاً يعني أن الدفع لا معنى له: من دفع مرّةً
--  نال الأبد. فتُسحب الميزة عند الانتهاء، ولا تُسحب ممّن له اشتراكٌ آخر قائم.
-- ----------------------------------------------------------------------------
create or replace function public.expire_subscriptions()
returns integer language plpgsql security definer set search_path = public as $$
declare
  n integer;
  touched uuid[];
begin
  -- **جملتان لا جملة.** كتبتُها أوّلَ مرّة تعديلاً واحداً: `with done as (update
  -- … returning provider_id) update service_providers … where id in (select …
  -- from done) and not exists (اشتراكٌ نشطٌ مميّز)`. وسقطت — لأن تعديلات الـCTE
  -- **لا تراها بقيّةُ الجملة**: كلُّ أجزائها تقرأ لقطةً واحدة. فشرطُ «لا اشتراك
  -- نشطاً» كان يرى الاشتراكَ الذي انتهى للتوّ نشطاً بعدُ، فلا يُسحب شيء.
  -- والاختبار هو الذي قاله: الحالة صارت «منتهياً» والمزوّد بقي مميّزاً.
  with done as (
    update public.provider_subscriptions
       set status = 'expired'
     where status = 'active' and ends_at < now()
    returning provider_id
  )
  select count(*), coalesce(array_agg(distinct provider_id), '{}')
    into n, touched from done;

  -- ولا تُسحب الميزة إلا ممّن انتهى اشتراكه في هذه الدورة: من ميّزته الإدارة
  -- بقرارٍ تحريري لا اشتراكٍ يبقى كما هو.
  update public.service_providers p
     set is_featured = false
   where p.id = any(touched)
     and not exists (
       select 1 from public.provider_subscriptions s
        join public.subscription_plans pl on pl.id = s.plan_id
        where s.provider_id = p.id and s.status = 'active'
          and array_to_string(pl.perks, '،') like '%ظهور مميز%');

  return n;
end $$;

revoke execute on function public.expire_subscriptions() from public, authenticated;

-- ----------------------------------------------------------------------------
-- ٥. اشتراكي — للتطبيق
-- ----------------------------------------------------------------------------
create or replace function public.api_my_subscription()
returns public.provider_subscriptions
language sql stable security definer set search_path = public as $$
  select * from public.provider_subscriptions
   where provider_id = public.current_provider()
     and status in ('pending', 'active')
   order by ends_at desc
   limit 1
$$;

grant execute on function public.api_subscribe(uuid, text, text) to authenticated;
grant execute on function public.api_my_subscription() to authenticated;

commit;

-- ----------------------------------------------------------------------------
-- ٦. جدولُ الانتهاء — إن أمكن
-- ----------------------------------------------------------------------------
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron غير متاح — نادِ expire_subscriptions() يدوياً.';
    return;
  end;

  perform cron.unschedule('expire-subscriptions')
    where exists (select 1 from cron.job where jobname = 'expire-subscriptions');
  perform cron.schedule('expire-subscriptions', '17 3 * * *',
                        'select public.expire_subscriptions()');
  raise notice 'جُدول الانتهاء يومياً.';
exception when others then
  raise notice 'تعذّرت الجدولة — نادِ expire_subscriptions() يدوياً.';
end $$;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'دالّة الاشتراك' as البند,
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_subscribe')
       then '✅' else '❌' end as الحال
union all
select 'مُشغِّل التفعيل بالدفع',
       case when exists (select 1 from pg_trigger where tgname = 'subscription_paid')
       then '✅' else '❌' end
union all
select 'حالة «معلّق» في القيد',
       case when exists (
         select 1 from pg_constraint
          where conname = 'provider_subscriptions_status_check'
            and pg_get_constraintdef(oid) like '%pending%')
       then '✅' else '❌' end;
