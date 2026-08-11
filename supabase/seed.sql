-- ============================================================================
--  بيانات أولية اختيارية — شغّلها بعد schema.sql
--
--  الهدف: مشروع جديد يعرض لوحة مليئة بالبيانات فوراً بدل شاشات فارغة.
--  آمنة للتكرار: تحذف البيانات المولّدة سابقاً ثم تعيد توليدها.
--  ⚠️  لا تشغّلها على قاعدة بيانات فيها بيانات حقيقية.
-- ============================================================================

begin;

delete from public.provider_reviews;
delete from public.provider_services;
delete from public.provider_documents;
delete from public.service_providers;
delete from public.ticket_messages;
delete from public.support_tickets;
delete from public.purchases;
delete from public.user_devices;
delete from public.user_sessions;
delete from public.app_users;
delete from public.daily_metrics;
delete from public.push_notifications;
delete from public.app_versions;

-- ----------------------------------------------------------------------------
-- المستخدمون — 80 مستخدماً بأسماء ودول متنوّعة
-- ----------------------------------------------------------------------------
insert into public.app_users
  (full_name, email, phone, platform, country, status, app_version, sessions_count, created_at, last_seen_at)
select
  (array['أحمد','محمد','عبدالله','خالد','يوسف','عمر','فاطمة','مريم','نورة','سارة'])[1 + (i % 10)]
    || ' ' ||
  (array['العتيبي','الحربي','القحطاني','الشمري','الزهراني','المالكي','حسن','إبراهيم'])[1 + (i % 8)],
  'user' || lpad(i::text, 4, '0') || '@example.com',
  case when i % 4 = 0 then null else '+9665' || lpad((10000000 + i * 137)::text, 8, '0') end,
  case when i % 5 < 3 then 'android' else 'ios' end,
  (array['السعودية','مصر','الإمارات','المغرب','الأردن','الكويت','الجزائر','قطر','تونس','عُمان'])[1 + (i % 10)],
  case when i % 13 = 0 then 'suspended' when i % 7 = 0 then 'pending' else 'active' end,
  (array['3.4.0','3.3.2','3.3.0','3.2.1','3.1.0'])[1 + (i % 5)],
  case when i % 7 = 0 then 0 else 10 + (i * 17) % 470 end,
  now() - ((i * 4) % 320 || ' days')::interval,
  case when i % 7 = 0 then null else now() - ((i * 3) % 14 || ' days')::interval end
from generate_series(1, 80) as i;

-- ----------------------------------------------------------------------------
-- الجلسات والأجهزة والمشتريات — مرتبطة بالمستخدمين أعلاه
-- ----------------------------------------------------------------------------
insert into public.user_sessions (user_id, started_at, duration_seconds, platform, app_version, country)
select u.id,
       now() - ((s * 2) || ' days')::interval - ((s * 7) || ' hours')::interval,
       120 + (s * 173) % 2400,
       u.platform,
       u.app_version,
       u.country
from public.app_users u
cross join generate_series(1, 8) as s
where u.status <> 'pending';

insert into public.user_devices (user_id, model, os_version, platform, push_enabled, last_used_at)
select u.id,
       case u.platform
         when 'ios' then (array['iPhone 15 Pro','iPhone 14','iPhone 13 mini','iPad Air'])[1 + (abs(hashtext(u.id::text)) % 4)]
         else (array['Samsung Galaxy S24','Xiaomi 14','Pixel 8','Oppo Reno 11'])[1 + (abs(hashtext(u.id::text)) % 4)]
       end,
       case u.platform when 'ios' then '18.2' else '15' end,
       u.platform,
       abs(hashtext(u.id::text)) % 5 <> 0,
       coalesce(u.last_seen_at, u.created_at)
from public.app_users u
where u.status <> 'pending';

insert into public.purchases (user_id, product, amount, status, created_at)
select u.id,
       (array['اشتراك شهري','اشتراك سنوي','باقة نقاط 100','إزالة الإعلانات'])[1 + (p % 4)],
       (array[29.00, 299.00, 19.00, 49.00])[1 + (p % 4)],
       case when p % 11 = 0 then 'refunded' when p % 17 = 0 then 'failed' else 'paid' end,
       now() - ((p * 11) % 180 || ' days')::interval
from public.app_users u
cross join generate_series(1, 3) as p
where u.status = 'active' and abs(hashtext(u.id::text)) % 3 = 0;

-- ----------------------------------------------------------------------------
-- المقاييس اليومية — 90 يوماً × منصتين، باتجاه صاعد وانخفاض في العطلة
-- ----------------------------------------------------------------------------
insert into public.daily_metrics (day, platform, installs, sessions, active_users, revenue)
select
  d::date,
  p,
  base,
  base * (9 + (extract(day from d)::int % 4)),
  (base * (9 + (extract(day from d)::int % 4)) / 2.4)::int,
  round((base * (11 + (extract(day from d)::int % 7)))::numeric, 2)
from generate_series(current_date - 89, current_date, interval '1 day') as d
cross join lateral (values ('ios'), ('android')) as plat(p)
cross join lateral (
  select (
    (case when p = 'android' then 105 else 75 end)
    + (current_date - d::date) * -0.9              -- اتجاه صاعد باتجاه اليوم
  ) * (case when extract(dow from d) in (5, 6) then 0.82 else 1 end)
  * (1 + ((extract(doy from d)::int % 7) - 3) * 0.03)
)::int as base;

-- ----------------------------------------------------------------------------
-- الإصدارات
-- ----------------------------------------------------------------------------
insert into public.app_versions (platform, version, build, released_at, force_update, rollout_percent, notes)
values
  ('ios',     '3.4.0', 3401, now() - interval '6 days',  false, 100, 'تحسين سرعة الإقلاع بنسبة 30% وإصلاح تعطّل شاشة الدفع.'),
  ('android', '3.4.0', 3402, now() - interval '5 days',  false,  60, 'نفس تحديثات iOS مع دعم الوضع الليلي على أندرويد 15.'),
  ('ios',     '3.3.2', 3322, now() - interval '28 days', true,  100, 'إصلاح ثغرة في تجديد الجلسة — التحديث إجباري.'),
  ('android', '3.3.0', 3300, now() - interval '44 days', false, 100, 'إضافة الإشعارات داخل التطبيق.');

-- ----------------------------------------------------------------------------
-- الإشعارات
-- ----------------------------------------------------------------------------
insert into public.push_notifications (title, body, audience, status, scheduled_at, sent_at, recipients, opened)
values
  ('خصم 25% لنهاية الأسبوع', 'استخدم كود WEEKEND25 عند إتمام الطلب قبل يوم الأحد.', 'all', 'sent', null, now() - interval '1 day', 18420, 7361),
  ('تحديث جديد متاح', 'النسخة 3.4.0 أصبحت متاحة مع تحسينات في السرعة وإصلاح الأعطال.', 'ios', 'sent', null, now() - interval '4 days', 7940, 2418),
  ('اشتقنا لك 👋', 'لم نرَك منذ فترة — تفقّد الجديد في التطبيق.', 'inactive', 'scheduled', now() + interval '2 days', null, 3120, 0),
  ('صيانة مجدولة', 'سيتوقف التطبيق مؤقتاً يوم الجمعة من 2 إلى 4 فجراً.', 'all', 'draft', null, null, 0, 0),
  ('مرحباً بك في التطبيق', 'ابدأ بإكمال ملفك الشخصي للحصول على توصيات أفضل.', 'active', 'sent', null, now() - interval '14 days', 15230, 8102);

-- ----------------------------------------------------------------------------
-- البلاغات ورسائلها
-- ----------------------------------------------------------------------------
with picked as (
  select id, full_name, email, row_number() over (order by created_at) as n
  from public.app_users
  limit 12
)
insert into public.support_tickets (user_id, user_name, user_email, subject, category, status, priority, created_at, updated_at)
select
  p.id, p.full_name, p.email,
  (array[
    'التطبيق يتوقف عند فتح شاشة الدفع',
    'لم يصلني إيصال الاشتراك',
    'لا أستطيع تسجيل الدخول برقم الجوال',
    'طلب إضافة الوضع الليلي',
    'خُصم المبلغ مرتين'
  ])[1 + (p.n % 5)],
  (array['bug','billing','account','feature','billing'])[1 + (p.n % 5)],
  (array['open','pending','resolved','closed'])[1 + (p.n % 4)],
  (array['urgent','high','normal','low'])[1 + (p.n % 4)],
  now() - (p.n || ' days')::interval,
  now() - (p.n || ' days')::interval + interval '3 hours'
from picked p;

insert into public.ticket_messages (ticket_id, author, author_email, body, created_at)
select t.id, 'user', t.user_email,
       'السلام عليكم، أواجه هذه المشكلة منذ آخر تحديث. أرجو المساعدة.',
       t.created_at
from public.support_tickets t;

insert into public.ticket_messages (ticket_id, author, author_email, body, created_at)
select t.id, 'admin', 'support@example.com',
       'وعليكم السلام، شكراً لتواصلك. نعمل على المشكلة وسنوافيك بالتحديث قريباً.',
       t.created_at + interval '3 hours'
from public.support_tickets t
where t.status <> 'open';

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة ومستنداتهم وخدماتهم وتقييماتهم
-- ----------------------------------------------------------------------------
insert into public.service_providers
  (full_name, business_name, email, phone, category, city, status, rating,
   reviews_count, completed_orders, total_earnings, commission_percent, joined_at, verified_at)
select
  (array['سعد','ماجد','فهد','بدر','تركي','ريان','هند','لمياء','غادة','منى'])[1 + (i % 10)]
    || ' ' ||
  (array['السبيعي','الغامدي','الرشيد','البقمي','المطيري','الجهني','العنزي','الخالدي'])[1 + (i % 8)],
  'مؤسسة ' || (array['الإتقان','النخبة','الرواد','البناء','السرعة','الأمانة'])[1 + (i % 6)] || ' للخدمات',
  'provider' || lpad(i::text, 3, '0') || '@example.com',
  '+9665' || lpad((20000000 + i * 971)::text, 8, '0'),
  (array['سباكة','كهرباء','تنظيف','تكييف','نجارة','دهان','نقل أثاث','صيانة أجهزة'])[1 + (i % 8)],
  (array['الرياض','جدة','الدمام','مكة','المدينة','الخبر','أبها','تبوك'])[1 + (i % 8)],
  st.status,
  case when st.status in ('active', 'suspended') then round((3.4 + (i % 16) * 0.1)::numeric, 1) else 0 end,
  case when st.status in ('active', 'suspended') then 4 + (i * 7) % 120 else 0 end,
  case when st.status in ('active', 'suspended') then 12 + (i * 13) % 380 else 0 end,
  case when st.status in ('active', 'suspended') then round((1500 + (i * 811) % 68000)::numeric, 2) else 0 end,
  (array[10, 12, 15, 15, 18, 20])[1 + (i % 6)],
  now() - ((i * 6) % 400 || ' days')::interval,
  case when st.status in ('active', 'suspended')
       then now() - ((i * 6) % 400 || ' days')::interval + interval '3 days'
       else null end
from generate_series(1, 32) as i
cross join lateral (
  select case
    when i % 9 = 0 then 'rejected'
    when i % 5 = 0 then 'pending'
    when i % 11 = 0 then 'suspended'
    else 'active'
  end as status
) as st;

insert into public.provider_documents (provider_id, type, file_name, status, note, uploaded_at)
select p.id,
       d.type,
       d.type || '-' || left(p.id::text, 8) || '.pdf',
       case
         when p.status = 'pending' then 'pending'
         when p.status = 'rejected' and d.type = 'commercial_register' then 'rejected'
         else 'approved'
       end,
       case
         when p.status = 'rejected' and d.type = 'commercial_register'
         then 'السجل التجاري منتهي الصلاحية.'
         else ''
       end,
       p.joined_at + interval '1 day'
from public.service_providers p
cross join lateral (values ('id_card'), ('commercial_register'), ('certificate')) as d(type);

insert into public.provider_services (provider_id, title, price, duration_minutes, active)
select p.id,
       p.category || ' — ' || (array['زيارة معاينة','خدمة أساسية','باقة صيانة شاملة'])[s],
       (array[80, 220, 650])[s],
       (array[30, 90, 240])[s],
       p.status = 'active'
from public.service_providers p
cross join generate_series(1, 3) as s
where p.status in ('active', 'suspended');

insert into public.provider_reviews (provider_id, user_name, rating, comment, created_at)
select p.id,
       (array['أحمد العتيبي','مريم حسن','خالد الحربي','نورة القحطاني','يوسف صالح'])[1 + (r % 5)],
       greatest(1, least(5, round(p.rating)::int + (case when r % 4 = 0 then -1 else 0 end))),
       (array[
         'خدمة ممتازة والتزام بالموعد.',
         'العمل جيد لكن التأخير كان ملحوظاً.',
         'أنصح به، سعر مناسب وجودة عالية.',
         'أنهى المهمة بسرعة وترك المكان نظيفاً.',
         'تعامل محترم وشرح المشكلة بوضوح.'
       ])[1 + (r % 5)],
       now() - ((r * 9) % 120 || ' days')::interval
from public.service_providers p
cross join generate_series(1, 4) as r
where p.status in ('active', 'suspended');

commit;

-- ============================================================================
--  ملاحظة: سجل العمليات (audit_log) يُترك فارغاً عمداً — يُفترض أن يمتلئ من
--  أفعال حقيقية داخل اللوحة، لا من بيانات مولّدة.
-- ============================================================================
