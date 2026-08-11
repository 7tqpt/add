-- ============================================================================
--  بيانات أولية اختيارية — شغّلها بعد schema.sql
--
--  الهدف: مشروع جديد يعرض لوحة مليئة بالبيانات فوراً بدل شاشات فارغة.
--  آمنة للتكرار: تحذف البيانات المولّدة سابقاً ثم تعيد توليدها.
--  ⚠️  لا تشغّلها على قاعدة بيانات فيها بيانات حقيقية.
-- ============================================================================

begin;

delete from public.settlement_items;
delete from public.settlements;
delete from public.conversation_messages;
delete from public.conversations;
delete from public.dispute_messages;
delete from public.disputes;
delete from public.reviews;
delete from public.payments;
delete from public.bookings;
delete from public.wedding_plans;
delete from public.promotions;
delete from public.provider_subscriptions;
delete from public.subscription_plans;
delete from public.provider_availability;
delete from public.provider_services;
delete from public.provider_documents;
delete from public.provider_categories;
delete from public.service_providers;
delete from public.user_devices;
delete from public.user_sessions;
delete from public.app_users;
delete from public.cancellation_policies;
delete from public.service_categories;
delete from public.governorates;
delete from public.daily_metrics;
delete from public.push_notifications;
delete from public.app_versions;

-- ----------------------------------------------------------------------------
-- المحافظات
-- ----------------------------------------------------------------------------
insert into public.governorates (name, sort_order) values
  ('أمانة العاصمة', 1), ('صنعاء', 2), ('عدن', 3), ('تعز', 4), ('الحديدة', 5),
  ('حضرموت', 6), ('إب', 7), ('ذمار', 8), ('حجة', 9), ('مأرب', 10),
  ('لحج', 11), ('أبين', 12), ('شبوة', 13), ('عمران', 14), ('صعدة', 15),
  ('البيضاء', 16), ('الضالع', 17), ('المهرة', 18), ('ريمة', 19), ('الجوف', 20);

-- ----------------------------------------------------------------------------
-- أقسام الخدمات الأحد عشر كما وردت في وثيقة المشروع
-- ----------------------------------------------------------------------------
insert into public.service_categories (name, slug, description, sort_order, custom_fields) values
  ('القاعات والخيام', 'halls',
   'صالات، خيام، استراحات، السعة، الموقع، الصور، الأسعار والمواعيد المتاحة.', 1,
   '[{"key":"capacity","label":"السعة","type":"number","required":true},
     {"key":"has_parking","label":"يوجد موقف سيارات","type":"boolean","required":false},
     {"key":"indoor","label":"مغلقة","type":"boolean","required":false}]'::jsonb),

  ('الفنانين والفرق', 'artists',
   'فنانين، فرق فنية، منشدين، دي جي، زفة، وفنانين مع معداتهم.', 2,
   '[{"key":"members","label":"عدد أفراد الفرقة","type":"number","required":false},
     {"key":"genre","label":"النوع","type":"text","required":false}]'::jsonb),

  ('الصوت والمعدات', 'sound',
   'سماعات، مكبرات، ميكروفونات، أجهزة دي جي، معدات صوت وحفلات وتأجير المعدات.', 3,
   '[{"key":"coverage_area","label":"مساحة التغطية","type":"text","required":false}]'::jsonb),

  ('التصوير والإضاءة', 'photography',
   'مصورين، فرق تصوير، تصوير فيديو وفوتوغرافي، كاميرات، درون، وإضاءة الحفلات والمسرح.', 4,
   '[{"key":"has_drone","label":"تصوير بالدرون","type":"boolean","required":false},
     {"key":"team_size","label":"عدد المصورين","type":"number","required":false}]'::jsonb),

  ('الموية والطليع والخدمات المساندة', 'support',
   'موية، قريح، طليع وأي خدمات مساندة يعتمدها النظام حسب المدينة.', 5,
   '[{"key":"quantity_unit","label":"وحدة القياس","type":"text","required":false}]'::jsonb),

  ('السيارات', 'cars',
   'سيارات للعريس، الزفة، الضيوف، سيارات فخمة، باصات وخدمات نقل.', 6,
   '[{"key":"car_model","label":"الطراز","type":"text","required":false},
     {"key":"seats","label":"عدد الركاب","type":"number","required":false}]'::jsonb),

  ('الملبوسات', 'attire',
   'ملابس العريس والعروس والضيوف والأطفال، شراء، إيجار، تفصيل وإكسسوارات.', 7,
   '[{"key":"mode","label":"نوع التعامل","type":"text","required":false}]'::jsonb),

  ('متعهدين الحفلات', 'planners',
   'تنظيم وتجهيز شامل، باقات، تنسيق الخدمات، الديكور، الصوت، التصوير والزفة.', 8,
   '[{"key":"package_scope","label":"نطاق الباقة","type":"text","required":false}]'::jsonb),

  ('التجميل والكوافير', 'beauty',
   'مكياج، تسريحات، كوافير، تجهيز العروس وخدمات التجميل.', 9,
   '[{"key":"home_service","label":"خدمة منزلية","type":"boolean","required":false}]'::jsonb),

  ('الديكور والكوشة والورد', 'decor',
   'كوش، ورد، ديكور، خلفيات، طاولات، كراسي وتجهيزات المكان.', 10,
   '[{"key":"style","label":"الطراز","type":"text","required":false}]'::jsonb),

  ('الطباعة', 'printing',
   'بطاقات الدعوة، اللوحات، الاستيكرات، التوزيعات، أرقام الطاولات، بطاقات الشكر والبنرات.', 11,
   '[{"key":"min_quantity","label":"أقل كمية","type":"number","required":false}]'::jsonb);

-- ----------------------------------------------------------------------------
-- سياسات الإلغاء — سلّم تنازلي: كلما اقترب الموعد قلّت النسبة المستردة
-- ----------------------------------------------------------------------------
insert into public.cancellation_policies (name, description, rules, is_default) values
  ('مرنة', 'استرداد كامل قبل 7 أيام من الموعد، ونصف المبلغ قبل 48 ساعة.',
   '[{"hours_before":168,"refund_percent":100},
     {"hours_before":48,"refund_percent":50},
     {"hours_before":0,"refund_percent":0}]'::jsonb, true),
  ('متوسطة', 'استرداد كامل قبل 14 يوماً، و50% قبل 7 أيام، و25% قبل 72 ساعة.',
   '[{"hours_before":336,"refund_percent":100},
     {"hours_before":168,"refund_percent":50},
     {"hours_before":72,"refund_percent":25},
     {"hours_before":0,"refund_percent":0}]'::jsonb, false),
  ('صارمة', 'استرداد 50% فقط قبل 30 يوماً، ولا استرداد بعدها — للقاعات والمواسم.',
   '[{"hours_before":720,"refund_percent":50},
     {"hours_before":0,"refund_percent":0}]'::jsonb, false);

-- ----------------------------------------------------------------------------
-- المستخدمون
-- ----------------------------------------------------------------------------
insert into public.app_users
  (full_name, email, phone, platform, governorate_id, governorate, status,
   app_version, sessions_count, created_at, last_seen_at)
select
  (array['أحمد','محمد','عبدالله','خالد','يوسف','عمر','فاطمة','مريم','نورة','سارة',
         'صالح','عبدالرحمن','هدى','أسماء','ريم','بلقيس'])[1 + (i % 16)]
    || ' ' ||
  (array['الحضرمي','الصنعاني','العديني','التعزي','الحديدي','المقطري','باسلامة',
         'الشرعبي','الأهدل','الوصابي'])[1 + (i % 10)],
  'user' || lpad(i::text, 4, '0') || '@example.com',
  '+9677' || lpad((10000000 + i * 137)::text, 8, '0'),
  case when i % 5 < 3 then 'android' else 'ios' end,
  g.id, g.name,
  case when i % 17 = 0 then 'suspended' when i % 9 = 0 then 'pending' else 'active' end,
  (array['1.4.0','1.3.2','1.3.0','1.2.1'])[1 + (i % 4)],
  case when i % 9 = 0 then 0 else 5 + (i * 17) % 260 end,
  now() - ((i * 4) % 300 || ' days')::interval,
  case when i % 9 = 0 then null else now() - ((i * 3) % 14 || ' days')::interval end
from generate_series(1, 90) as i
cross join lateral (
  select id, name from public.governorates order by sort_order
  offset (i % 8) limit 1
) as g;

insert into public.user_sessions (user_id, started_at, duration_seconds, platform, app_version, governorate)
select u.id,
       now() - ((s * 2) || ' days')::interval - ((s * 5) || ' hours')::interval,
       180 + (s * 211) % 2600,
       u.platform, u.app_version, u.governorate
from public.app_users u
cross join generate_series(1, 6) as s
where u.status <> 'pending';

insert into public.user_devices (user_id, model, os_version, platform, push_enabled, last_used_at)
select u.id,
       case u.platform
         when 'ios' then (array['iPhone 13','iPhone 12','iPhone 11','iPhone SE'])[1 + (abs(hashtext(u.id::text)) % 4)]
         else (array['Samsung Galaxy A54','Redmi Note 12','Infinix Hot 30','Tecno Spark 10'])[1 + (abs(hashtext(u.id::text)) % 4)]
       end,
       case u.platform when 'ios' then '17.4' else '13' end,
       u.platform,
       abs(hashtext(u.id::text)) % 5 <> 0,
       coalesce(u.last_seen_at, u.created_at)
from public.app_users u
where u.status <> 'pending';

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة — موزّعون على الأقسام والمحافظات وبحالات مختلفة
-- ----------------------------------------------------------------------------
insert into public.service_providers
  (full_name, business_name, email, phone, bio, governorate_id, governorate,
   coverage_areas, status, is_featured, rating, reviews_count, completed_bookings,
   total_earnings, applied_at, verified_at, created_at)
select
  (array['سعد','ماجد','فهد','بدر','ريان','هند','لمياء','غادة','منى','وليد',
         'عصام','أنور'])[1 + (i % 12)]
    || ' ' ||
  (array['باعوم','الحبيشي','الرداعي','السقاف','الجنيد','المخلافي','بن شملان',
         'الزبيري'])[1 + (i % 8)],
  (array['قاعة','مؤسسة','استوديو','مركز','معرض','فرقة'])[1 + (i % 6)] || ' ' ||
  (array['اللؤلؤة','الأصالة','النخبة','الياسمين','بلقيس','السعادة','الفردوس','التاج'])[1 + (i % 8)],
  'provider' || lpad(i::text, 3, '0') || '@example.com',
  '+9677' || lpad((70000000 + i * 971)::text, 8, '0'),
  'خبرة تتجاوز ' || (3 + i % 12)::text || ' سنوات في تجهيز الأعراس.',
  g.id, g.name,
  array[g.name],
  st.status,
  (i % 13 = 0),
  case when st.status in ('verified', 'suspended') then round((3.5 + (i % 15) * 0.1)::numeric, 1) else 0 end,
  case when st.status in ('verified', 'suspended') then 3 + (i * 7) % 80 else 0 end,
  case when st.status in ('verified', 'suspended') then 5 + (i * 11) % 160 else 0 end,
  case when st.status in ('verified', 'suspended') then round((150000 + (i * 81100) % 7000000)::numeric, 2) else 0 end,
  now() - ((i * 7) % 380 || ' days')::interval,
  case when st.status in ('verified', 'suspended')
       then now() - ((i * 7) % 380 || ' days')::interval + interval '4 days' else null end,
  now() - ((i * 7) % 380 || ' days')::interval
from generate_series(1, 44) as i
cross join lateral (
  select id, name from public.governorates order by sort_order offset (i % 8) limit 1
) as g
cross join lateral (
  select case
    when i % 12 = 0 then 'rejected'
    when i % 7 = 0 then 'pending'
    when i % 19 = 0 then 'suspended'
    else 'verified'
  end as status
) as st;

-- كل مقدّم خدمة يُسند إلى قسم رئيسي، وثلثهم إلى قسم ثانٍ
insert into public.provider_categories (provider_id, category_id)
select p.id, c.id
from public.service_providers p
cross join lateral (
  select id from public.service_categories
  order by sort_order offset (abs(hashtext(p.id::text)) % 11) limit 1
) as c;

insert into public.provider_categories (provider_id, category_id)
select p.id, c.id
from public.service_providers p
cross join lateral (
  select id from public.service_categories
  order by sort_order offset ((abs(hashtext(p.id::text)) + 4) % 11) limit 1
) as c
where abs(hashtext(p.id::text)) % 3 = 0
on conflict do nothing;

insert into public.provider_documents (provider_id, type, file_name, status, note, uploaded_at, reviewed_at)
select p.id, d.type,
       d.type || '-' || left(p.id::text, 8) || '.pdf',
       case
         when p.status = 'pending' then 'pending'
         when p.status = 'rejected' and d.type = 'commercial_register' then 'rejected'
         else 'approved'
       end,
       case when p.status = 'rejected' and d.type = 'commercial_register'
            then 'السجل التجاري منتهي الصلاحية.' else '' end,
       p.applied_at + interval '1 day',
       case when p.status = 'pending' then null else p.applied_at + interval '3 days' end
from public.service_providers p
cross join lateral (values ('id_card'), ('commercial_register'), ('work_samples')) as d(type);

-- ----------------------------------------------------------------------------
-- الخدمات المعروضة — أسعار بالريال اليمني، ونسب عربون، وسياسة إلغاء لكل خدمة
-- ----------------------------------------------------------------------------
insert into public.provider_services
  (provider_id, category_id, title, description, price, price_to, unit,
   deposit_percent, duration_minutes, cancellation_policy_id, attributes, is_active)
select
  pc.provider_id,
  pc.category_id,
  c.name || ' — ' || (array['باقة أساسية','باقة متوسطة','باقة شاملة'])[s],
  'تشمل الباقة تجهيزاً كاملاً مع فريق مختص وضمان جودة التنفيذ.',
  base.price * s,
  base.price * s + base.price / 2,
  case c.slug when 'printing' then 'لكل 100 بطاقة' when 'cars' then 'لليوم' else 'للحجز' end,
  (array[20, 30, 50])[s],
  (array[120, 240, 480])[s],
  pol.id,
  '{}'::jsonb,
  p.status = 'verified'
from public.provider_categories pc
join public.service_providers p on p.id = pc.provider_id
join public.service_categories c on c.id = pc.category_id
cross join generate_series(1, 3) as s
cross join lateral (
  select case c.slug
    when 'halls'       then 300000
    when 'artists'     then 200000
    when 'sound'       then 90000
    when 'photography' then 120000
    when 'support'     then 40000
    when 'cars'        then 60000
    when 'attire'      then 80000
    when 'planners'    then 400000
    when 'beauty'      then 50000
    when 'decor'       then 150000
    else 20000
  end::numeric as price
) as base
cross join lateral (
  -- القاعات تأخذ السياسة الصارمة، وبقية الأقسام المرنة
  select id from public.cancellation_policies
  where name = (case when c.slug = 'halls' then 'صارمة' else 'مرنة' end)
  limit 1
) as pol
where p.status in ('verified', 'suspended');

-- ----------------------------------------------------------------------------
-- خطط الأعراس
-- ----------------------------------------------------------------------------
insert into public.wedding_plans
  (user_id, title, wedding_date, governorate_id, governorate, guests_count, budget, status, notes, created_at)
select
  u.id,
  'عرس ' || split_part(u.full_name, ' ', 1),
  (current_date + ((abs(hashtext(u.id::text)) % 150) - 40))::date,
  u.governorate_id, u.governorate,
  150 + (abs(hashtext(u.id::text)) % 650),
  round((1500000 + (abs(hashtext(u.id::text)) % 9000000))::numeric, 2),
  case
    when (current_date + ((abs(hashtext(u.id::text)) % 150) - 40)) < current_date then 'completed'
    when abs(hashtext(u.id::text)) % 11 = 0 then 'cancelled'
    when abs(hashtext(u.id::text)) % 3 = 0 then 'confirmed'
    else 'planning'
  end,
  'تجهيز العرس بالكامل عبر المنصة.',
  now() - ((abs(hashtext(u.id::text)) % 90) || ' days')::interval
from public.app_users u
where u.status = 'active' and abs(hashtext(u.id::text)) % 3 = 0;

-- ----------------------------------------------------------------------------
-- الحجوزات — حجز مباشر على خدمة مقدّم خدمة موثّق، بحالات تغطي دورة الحياة
-- ----------------------------------------------------------------------------
insert into public.bookings
  (reference, user_id, user_name, provider_id, provider_name, service_id, service_title,
   category_id, category_name, plan_id, event_date, event_time, governorate, address,
   guests_count, notes, status, total_price, deposit_amount, paid_amount, refunded_amount,
   commission_percent, commission_amount, cancellation_rules,
   rejection_reason, cancel_reason, created_at, confirmed_at, completed_at, cancelled_at)
select
  'BK-' || to_char(now(), 'YYYY') || '-' || lpad(row_number() over ()::text, 6, '0'),
  pl.user_id, u.full_name,
  p.id, p.business_name,
  sv.id, sv.title,
  sv.category_id, c.name,
  pl.id,
  pl.wedding_date,
  (array['16:00','18:00','20:00','21:30'])[1 + (n % 4)]::time,
  pl.governorate,
  'حي ' || (array['السنينة','حدة','الصافية','المعلا','الكمب','القاهرة'])[1 + (n % 6)],
  pl.guests_count,
  'يرجى التواجد قبل الموعد بساعة.',
  st.status,
  sv.price,
  round(sv.price * sv.deposit_percent / 100, 2),
  case st.status
    when 'confirmed' then sv.price
    when 'completed' then sv.price
    else round(sv.price * sv.deposit_percent / 100, 2)
  end,
  case st.status
    when 'rejected'  then round(sv.price * sv.deposit_percent / 100, 2)
    when 'cancelled' then round(sv.price * sv.deposit_percent / 100 / 2, 2)
    else 0
  end,
  10,
  case when st.status in ('confirmed', 'completed') then round(sv.price * 0.10, 2) else 0 end,
  coalesce(pol.rules, '[]'::jsonb),
  case when st.status = 'rejected' then 'الموعد محجوز مسبقاً لدينا.' else '' end,
  case when st.status = 'cancelled' then 'ألغى العميل بعد تغيير موعد العرس.' else '' end,
  pl.created_at + interval '2 days',
  case when st.status in ('confirmed', 'completed')
       then pl.created_at + interval '3 days' else null end,
  case when st.status = 'completed' then pl.wedding_date + interval '1 day' else null end,
  case when st.status in ('cancelled', 'rejected')
       then pl.created_at + interval '4 days' else null end
from public.wedding_plans pl
join public.app_users u on u.id = pl.user_id
cross join generate_series(1, 3) as n
cross join lateral (
  select sv.id, sv.title, sv.price, sv.deposit_percent, sv.category_id, sv.provider_id,
         sv.cancellation_policy_id
  from public.provider_services sv
  join public.service_providers sp on sp.id = sv.provider_id
  where sv.is_active and sp.status = 'verified'
  order by md5(sv.id::text || pl.id::text || n::text)
  limit 1
) as sv
join public.service_providers p on p.id = sv.provider_id
join public.service_categories c on c.id = sv.category_id
left join public.cancellation_policies pol on pol.id = sv.cancellation_policy_id
cross join lateral (
  select case
    when (abs(hashtext(pl.id::text)) + n) % 13 = 0 then 'rejected'
    when (abs(hashtext(pl.id::text)) + n) % 11 = 0 then 'cancelled'
    when (abs(hashtext(pl.id::text)) + n) % 5  = 0 then 'pending_provider'
    when pl.wedding_date < current_date then 'completed'
    else 'confirmed'
  end as status
) as st;

-- ----------------------------------------------------------------------------
-- المدفوعات — العربون لكل حجز، والمتبقي لما تأكد، والاسترداد لما أُلغي أو رُفض
-- ----------------------------------------------------------------------------
insert into public.payments
  (reference, user_id, user_name, provider_id, provider_name, booking_id, booking_reference,
   kind, description, amount, platform_share, net_amount, method, status, gateway_ref,
   created_at, refunded_at)
select
  'TRX-' || to_char(now(), 'YYYY') || '-' || lpad(row_number() over ()::text, 6, '0'),
  b.user_id, b.user_name, b.provider_id, b.provider_name, b.id, b.reference,
  'deposit', 'عربون حجز — ' || b.category_name,
  b.deposit_amount,
  round(b.deposit_amount * b.commission_percent / 100, 2),
  b.deposit_amount - round(b.deposit_amount * b.commission_percent / 100, 2),
  (array['jawali','cash_wallet','kuraimi','bank_transfer','card'])[1 + (abs(hashtext(b.id::text)) % 5)],
  case when b.status in ('rejected', 'cancelled') then 'refunded' else 'paid' end,
  'gw_' || substr(md5(b.id::text), 1, 12),
  b.created_at,
  case when b.status in ('rejected', 'cancelled') then b.cancelled_at else null end
from public.bookings b;

insert into public.payments
  (reference, user_id, user_name, provider_id, provider_name, booking_id, booking_reference,
   kind, description, amount, platform_share, net_amount, method, status, gateway_ref, created_at)
select
  'TRX-' || to_char(now(), 'YYYY') || '-' || lpad((100000 + row_number() over ())::text, 6, '0'),
  b.user_id, b.user_name, b.provider_id, b.provider_name, b.id, b.reference,
  'balance', 'سداد المتبقي — ' || b.category_name,
  b.total_price - b.deposit_amount,
  round((b.total_price - b.deposit_amount) * b.commission_percent / 100, 2),
  (b.total_price - b.deposit_amount)
    - round((b.total_price - b.deposit_amount) * b.commission_percent / 100, 2),
  (array['jawali','cash_wallet','kuraimi','bank_transfer','card'])[1 + (abs(hashtext(b.id::text)) % 5)],
  'paid',
  'gw_' || substr(md5(b.id::text || 'b'), 1, 12),
  coalesce(b.confirmed_at, b.created_at)
from public.bookings b
where b.status in ('confirmed', 'completed') and b.total_price > b.deposit_amount;

-- ----------------------------------------------------------------------------
-- التقييمات — للحجوزات المنفَّذة فقط، كما تشترط الوثيقة
-- ----------------------------------------------------------------------------
insert into public.reviews (booking_id, user_id, user_name, provider_id, rating, comment, status, created_at)
select b.id, b.user_id, b.user_name, b.provider_id,
       greatest(1, least(5, 3 + (abs(hashtext(b.id::text)) % 3))),
       (array[
         'خدمة ممتازة والتزام تام بالموعد، شكراً لكم.',
         'التنفيذ كان جيداً لكن التأخير في البداية أزعجنا.',
         'أنصح بهم بشدة، الجودة تستحق السعر.',
         'تعامل راقٍ وتنسيق جميل، وفّقكم الله.',
         'كل شيء تم كما اتفقنا تماماً.'
       ])[1 + (abs(hashtext(b.id::text)) % 5)],
       case when abs(hashtext(b.id::text)) % 23 = 0 then 'flagged' else 'published' end,
       b.completed_at + interval '2 days'
from public.bookings b
where b.status = 'completed' and abs(hashtext(b.id::text)) % 3 <> 0;

-- ----------------------------------------------------------------------------
-- النزاعات
-- ----------------------------------------------------------------------------
insert into public.disputes
  (reference, booking_id, booking_reference, opened_by, user_id, user_name,
   provider_id, provider_name, subject, description, category, status, resolution,
   refund_amount, resolved_by, created_at, resolved_at)
select
  'DSP-' || to_char(now(), 'YYYY') || '-' || lpad(row_number() over ()::text, 4, '0'),
  b.id, b.reference,
  case when abs(hashtext(b.id::text)) % 4 = 0 then 'provider' else 'customer' end,
  b.user_id, b.user_name, b.provider_id, b.provider_name,
  (array[
    'مقدم الخدمة لم يحضر في الموعد',
    'جودة التنفيذ أقل من المتفق عليه',
    'خُصم مبلغ إضافي دون اتفاق',
    'العميل ألغى في اللحظة الأخيرة',
    'خلاف على تفاصيل الباقة'
  ])[1 + (abs(hashtext(b.id::text)) % 5)],
  'تفاصيل الشكوى مرفقة مع المحادثات والإيصالات.',
  (array['no_show','quality','payment','cancellation','behaviour'])[1 + (abs(hashtext(b.id::text)) % 5)],
  d.status,
  case when d.status in ('resolved','closed') then 'تمت التسوية باتفاق الطرفين بعد مراجعة الإدارة.' else '' end,
  case when d.status = 'resolved' then round(b.paid_amount * 0.3, 2) else 0 end,
  case when d.status in ('resolved','closed') then 'admin@example.com' else '' end,
  b.created_at + interval '6 days',
  case when d.status in ('resolved','closed') then b.created_at + interval '9 days' else null end
from public.bookings b
cross join lateral (
  select (array['open','investigating','resolved','closed'])[1 + (abs(hashtext(b.id::text)) % 4)] as status
) as d
where abs(hashtext(b.id::text)) % 9 = 0;

insert into public.dispute_messages (dispute_id, author, author_name, body, created_at)
select d.id, 'customer', d.user_name,
       'السلام عليكم، أرجو النظر في المشكلة المذكورة وإفادتي.',
       d.created_at
from public.disputes d;

insert into public.dispute_messages (dispute_id, author, author_name, body, created_at)
select d.id, 'admin', 'فريق المنصة',
       'شكراً لتواصلك، تم فتح النزاع ونتواصل مع الطرف الآخر.',
       d.created_at + interval '4 hours'
from public.disputes d
where d.status <> 'open';

-- ----------------------------------------------------------------------------
-- المحادثات بين العميل ومقدّم الخدمة
-- ----------------------------------------------------------------------------
insert into public.conversations (booking_id, user_id, user_name, provider_id, provider_name, last_message_at, created_at)
select b.id, b.user_id, b.user_name, b.provider_id, b.provider_name,
       b.created_at + interval '1 day', b.created_at
from public.bookings b
where abs(hashtext(b.id::text)) % 4 = 0;

insert into public.conversation_messages (conversation_id, sender, body, created_at)
select cv.id, m.sender, m.body, cv.created_at + (m.offset_hours || ' hours')::interval
from public.conversations cv
cross join lateral (values
  ('customer', 'السلام عليكم، هل الموعد مؤكد؟', 1),
  ('provider', 'وعليكم السلام، نعم مؤكد وسنصل قبل الموعد بساعة.', 3),
  ('customer', 'ممتاز، شكراً لكم.', 5)
) as m(sender, body, offset_hours);

-- ----------------------------------------------------------------------------
-- التسويات — دفعة عن الشهر الماضي لكل مقدّم خدمة له حجوزات منفَّذة
-- ----------------------------------------------------------------------------
insert into public.settlements
  (reference, provider_id, provider_name, period_start, period_end,
   gross_amount, commission_amount, net_amount, status, method, created_at, paid_at)
select
  'STL-' || to_char(now(), 'YYYY') || '-' || lpad(row_number() over ()::text, 4, '0'),
  agg.provider_id, agg.provider_name,
  (date_trunc('month', current_date) - interval '1 month')::date,
  (date_trunc('month', current_date) - interval '1 day')::date,
  agg.gross, agg.commission, agg.gross - agg.commission,
  s.status, 'تحويل بنكي',
  date_trunc('month', current_date),
  case when s.status = 'paid' then date_trunc('month', current_date) + interval '3 days' else null end
from (
  select b.provider_id, b.provider_name,
         sum(b.paid_amount) as gross,
         sum(b.commission_amount) as commission
  from public.bookings b
  where b.status = 'completed' and b.provider_id is not null
  group by b.provider_id, b.provider_name
) as agg
cross join lateral (
  select (array['pending','approved','paid'])[1 + (abs(hashtext(agg.provider_id::text)) % 3)] as status
) as s;

insert into public.settlement_items (settlement_id, booking_id, gross_amount, commission_amount, net_amount)
select st.id, b.id, b.paid_amount, b.commission_amount, b.paid_amount - b.commission_amount
from public.settlements st
join public.bookings b on b.provider_id = st.provider_id and b.status = 'completed';

-- ----------------------------------------------------------------------------
-- الاشتراكات والباقات الترويجية
-- ----------------------------------------------------------------------------
insert into public.subscription_plans (name, description, price, duration_days, perks) values
  ('الباقة الأساسية', 'ظهور عادي وحتى 5 خدمات معروضة.', 0, 30,
   array['حتى 5 خدمات', 'ملف تعريفي أساسي']),
  ('الباقة الفضية', 'خدمات غير محدودة وأولوية في نتائج البحث.', 15000, 30,
   array['خدمات غير محدودة', 'أولوية في البحث', 'شارة نشط']),
  ('الباقة الذهبية', 'ظهور مميز في الصفحة الرئيسية وتقارير أداء شهرية.', 40000, 30,
   array['كل مزايا الفضية', 'ظهور مميز في الرئيسية', 'تقارير أداء', 'دعم مخصص']);

insert into public.provider_subscriptions (provider_id, plan_id, plan_name, amount, status, starts_at, ends_at)
select p.id, sp.id, sp.name, sp.price,
       case when abs(hashtext(p.id::text)) % 7 = 0 then 'expired' else 'active' end,
       now() - interval '20 days',
       now() + interval '10 days'
from public.service_providers p
cross join lateral (
  select id, name, price from public.subscription_plans
  order by price offset (abs(hashtext(p.id::text)) % 3) limit 1
) as sp
where p.status = 'verified';

insert into public.promotions
  (provider_id, provider_name, kind, placement, category_id, amount, status,
   impressions, clicks, starts_at, ends_at)
select p.id, p.business_name,
       (array['featured','banner','category_top'])[1 + (abs(hashtext(p.id::text)) % 3)],
       (array['home','search','category'])[1 + (abs(hashtext(p.id::text)) % 3)],
       pc.category_id,
       (array[25000, 50000, 80000])[1 + (abs(hashtext(p.id::text)) % 3)],
       case when abs(hashtext(p.id::text)) % 5 = 0 then 'ended' else 'active' end,
       1200 + (abs(hashtext(p.id::text)) % 18000),
       40 + (abs(hashtext(p.id::text)) % 900),
       now() - interval '15 days',
       now() + interval '15 days'
from public.service_providers p
join lateral (
  select category_id from public.provider_categories where provider_id = p.id limit 1
) as pc on true
where p.status = 'verified' and abs(hashtext(p.id::text)) % 3 = 0;

-- ----------------------------------------------------------------------------
-- المقاييس اليومية والإصدارات والإشعارات
-- ----------------------------------------------------------------------------
insert into public.daily_metrics (day, platform, installs, sessions, active_users, bookings_count, revenue)
select
  d::date, plat.p, base.n,
  base.n * (8 + (extract(day from d)::int % 4)),
  (base.n * (8 + (extract(day from d)::int % 4)) / 2.6)::int,
  greatest(0, (base.n / 12)::int),
  round((base.n * (2200 + (extract(day from d)::int % 900)))::numeric, 2)
from generate_series(current_date - 89, current_date, interval '1 day') as d
cross join lateral (values ('ios'), ('android')) as plat(p)
cross join lateral (
  select greatest(5, (
    (case when plat.p = 'android' then 90 else 55 end)
    + (current_date - d::date) * -0.7
  ) * (case when extract(dow from d) in (4, 5) then 1.18 else 1 end))::int as n
) as base;

insert into public.app_versions (platform, version, build, released_at, force_update, rollout_percent, notes) values
  ('ios',     '1.4.0', 1401, now() - interval '5 days',  false, 100, 'إضافة خطة العرس وتحسين سرعة البحث.'),
  ('android', '1.4.0', 1402, now() - interval '4 days',  false,  70, 'إضافة خطة العرس ودعم محفظة جوالي.'),
  ('ios',     '1.3.2', 1322, now() - interval '30 days', true,  100, 'إصلاح ثغرة في تجديد الجلسة — التحديث إجباري.'),
  ('android', '1.3.0', 1300, now() - interval '48 days', false, 100, 'إشعارات الحجز داخل التطبيق.');

insert into public.push_notifications (title, body, audience, status, scheduled_at, sent_at, recipients, opened) values
  ('موسم الأعراس بدأ 🎉', 'احجز قاعتك مبكراً واحصل على خصم 10% حتى نهاية الشهر.', 'customers', 'sent', null, now() - interval '2 days', 14200, 6180),
  ('وثّق حسابك الآن', 'أكمل رفع مستنداتك لتبدأ استقبال الحجوزات.', 'providers', 'sent', null, now() - interval '6 days', 320, 210),
  ('تذكير بموعد عرسك', 'بقي أسبوع على موعدك — راجع خطة العرس وتأكد من الحجوزات.', 'active', 'scheduled', now() + interval '3 days', null, 2400, 0),
  ('صيانة مجدولة', 'سيتوقف التطبيق مؤقتاً ليلة الجمعة من 2 إلى 4 فجراً.', 'all', 'draft', null, null, 0, 0);

-- ----------------------------------------------------------------------------
-- إعدادات المنصة للسوق اليمني
-- ----------------------------------------------------------------------------
update public.app_settings set
  commission_percent = 10,
  default_deposit_percent = 30,
  currency = 'YER',
  support_email = 'support@example.com',
  support_phone = '+967700000000',
  maintenance_message = 'نقوم بأعمال صيانة سريعة، عُد إلينا خلال ساعة.',
  updated_at = now()
where id = 1;

commit;

-- ============================================================================
--  ملاحظة: سجل العمليات (audit_log) يُترك فارغاً عمداً — يُفترض أن يمتلئ من
--  أفعال حقيقية داخل اللوحة، لا من بيانات مولّدة.
-- ============================================================================
