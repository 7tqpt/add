-- ============================================================================
--  الإعلانات: المزوّد يشتري ظهوراً في الرئيسية، والمنصّة تبيعه
--
--  شغّله بعد `subscriptions.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** جدول `promotions` كامل بحالاته وإحصاءاته، وصفحةٌ في
--  اللوحة تعرضه وتلغيه — ولا أحد يُنشئ صفّاً فيه. فبابُ الدخل الثالث مغلق:
--  عمولةُ الحجز، والاشتراك، وهذا.
--
--  **والسعر في الإعدادات لا في الشيفرة:** يتغيّر بالموسم — أسبوعُ العيد ليس
--  كأسبوعٍ في رمضان — وتغييرُه في الشيفرة يعني بناءً جديداً على كل جهاز.
--  وصفرٌ يعني «لم يُفتح البيع بعد»، فيُخفى الشراء بدل أن يُعرض بسعرٍ لا معنى له.
-- ============================================================================

begin;

alter table public.app_settings
  add column if not exists promo_featured_daily numeric(12, 2) not null default 0
    check (promo_featured_daily >= 0);

comment on column public.app_settings.promo_featured_daily is
  'سعرُ يومٍ واحد من الظهور المميز في الرئيسية. صفرٌ يُغلق البيع.';

-- الحوالةُ التي تخصّه — كما في الاشتراك، ولنفس السبب: التفعيل يُربط بالدفع
-- بلا تخمين.
alter table public.promotions
  add column if not exists payment_id uuid references public.payments (id) on delete set null;

-- طلبٌ واحدٌ معلّق لكل مزوّد.
create unique index if not exists promotions_one_pending
  on public.promotions (provider_id) where status = 'scheduled';

-- ----------------------------------------------------------------------------
-- الطلب
-- ----------------------------------------------------------------------------
create or replace function public.api_request_promotion(
  p_days integer, p_method text default 'jawali', p_sender_ref text default '')
returns public.promotions
language plpgsql security definer set search_path = public as $$
declare
  me    uuid := public.current_provider();
  prov  public.service_providers;
  price numeric(12, 2);
  total numeric(12, 2);
  pay   public.payments;
  promo public.promotions;
begin
  if me is null then
    raise exception 'الإعلانات لمقدّمي الخدمة';
  end if;
  if p_days is null or p_days < 1 or p_days > 90 then
    raise exception 'المدّة من يومٍ إلى تسعين';
  end if;

  select promo_featured_daily into price from public.app_settings where id = 1;
  if coalesce(price, 0) <= 0 then
    raise exception 'لم تُفتح مساحات الإعلان بعد';
  end if;

  if exists (select 1 from public.promotions
              where provider_id = me and status = 'scheduled') then
    raise exception 'لك طلبُ إعلانٍ قيد التأكيد';
  end if;

  total := price * p_days;
  select * into prov from public.service_providers where id = me;

  insert into public.payments
         (reference, user_id, user_name, provider_id, provider_name, kind,
          description, amount, platform_share, net_amount, method, status, gateway_ref)
  values ('PRM-' || to_char(now(), 'YYYYMM') || '-' ||
            upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
          prov.user_id, prov.full_name, me, prov.business_name, 'promotion',
          'ظهور مميز ' || p_days || ' يوماً', total, total, 0,
          p_method, 'pending', btrim(p_sender_ref))
  returning * into pay;

  -- المدّة تُحفظ في الفارق بين التاريخين، وتُعاد من لحظة التفعيل: من حوّل
  -- الخميس وأُكّدت حوالتُه السبت لا يُخصم منه يومان لم يظهر فيهما.
  insert into public.promotions
         (provider_id, provider_name, kind, placement, amount, status,
          starts_at, ends_at, payment_id)
  values (me, prov.business_name, 'featured', 'home', total, 'scheduled',
          now(), now() + make_interval(days => p_days), pay.id)
  returning * into promo;

  return promo;
end $$;

comment on function public.api_request_promotion(integer, text, text) is
  'يطلب مقدّمُ الخدمة ظهوراً مميزاً لمدّة. لا يُعرض حتى تُؤكَّد حوالته.';

-- ----------------------------------------------------------------------------
-- التفعيل بوصول المال — مُشغِّلاً، كالاشتراك
-- ----------------------------------------------------------------------------
create or replace function public.activate_paid_promotion()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  promo public.promotions;
  span  interval;
begin
  if new.kind <> 'promotion' or new.status <> 'paid'
     or old.status is not distinct from 'paid' then
    return new;
  end if;

  select * into promo from public.promotions
   where payment_id = new.id and status = 'scheduled';
  if not found then
    return new;
  end if;

  span := promo.ends_at - promo.starts_at;

  update public.promotions
     set status = 'active', starts_at = now(), ends_at = now() + span
   where id = promo.id;

  perform public.notify_provider(
    promo.provider_id, 'account', 'بدأ ظهورك المميز',
    'ملفّك في مقدّمة الرئيسية حتى ' || to_char(now() + span, 'YYYY-MM-DD') || '.',
    jsonb_build_object('promotion_id', promo.id)
  );

  return new;
end $$;

drop trigger if exists promotion_paid on public.payments;
create trigger promotion_paid
  after update of status on public.payments
  for each row execute function public.activate_paid_promotion();

-- ----------------------------------------------------------------------------
-- الانتهاء
-- ----------------------------------------------------------------------------
create or replace function public.expire_promotions()
returns integer language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  update public.promotions
     set status = 'ended'
   where status = 'active' and ends_at < now();
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.expire_promotions() from public, authenticated;

-- ----------------------------------------------------------------------------
-- الإعلانات القائمة — لعرضها في الرئيسية
--
--  ومعها اسمُ المزوّد وشعارُه في صفٍّ واحد: الشريط يعرض بطاقاتٍ، ونداءٌ لكل
--  بطاقةٍ يجعل الرئيسية تنتظر خمسة طلبات.
-- ----------------------------------------------------------------------------
create or replace function public.api_active_promotions()
returns table (
  id uuid, provider_id uuid, provider_name text, logo_path text,
  governorate text, rating numeric, ends_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select pr.id, pr.provider_id, p.business_name, p.logo_path,
         p.governorate, p.rating, pr.ends_at
    from public.promotions pr
    join public.service_providers p on p.id = pr.provider_id
   where pr.status = 'active'
     and now() between pr.starts_at and pr.ends_at
     and p.status = 'verified'
   order by pr.ends_at asc
   limit 10
$$;

grant execute on function public.api_request_promotion(integer, text, text) to authenticated;
grant execute on function public.api_active_promotions() to anon, authenticated;

commit;

-- ----------------------------------------------------------------------------
-- جدولُ الانتهاء — إن أمكن
-- ----------------------------------------------------------------------------
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron غير متاح — نادِ expire_promotions() يدوياً.';
    return;
  end;

  perform cron.unschedule('expire-promotions')
    where exists (select 1 from cron.job where jobname = 'expire-promotions');
  perform cron.schedule('expire-promotions', '23 3 * * *',
                        'select public.expire_promotions()');
  raise notice 'جُدول انتهاء الإعلانات يومياً.';
exception when others then
  raise notice 'تعذّرت الجدولة — نادِ expire_promotions() يدوياً.';
end $$;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'دالّة الطلب' as البند,
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_request_promotion')
       then '✅' else '❌' end as الحال
union all
select 'مُشغِّل التفعيل بالدفع',
       case when exists (select 1 from pg_trigger where tgname = 'promotion_paid')
       then '✅' else '❌' end
union all
select 'سعرُ اليوم',
       case when coalesce((select promo_featured_daily from public.app_settings
                            where id = 1), 0) > 0
       then '✅ مضبوط' else '⚠️ صفر — البيع مغلق حتى يُضبط من الإعدادات' end;
