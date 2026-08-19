-- ============================================================================
--  حذف البيانات التجريبية
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run.
--  ⚠️ لا رجعة فيه. اقرأ ما يلي قبل التشغيل.
--
--  ────────────────────────────────────────────────────────────────────────────
--  كيف يُميَّز التجريبيُّ من الحقيقي؟
--
--  لا بالأسماء — «مطابخ اللؤلؤة» اسمٌ قد يسجّله صاحبه غداً حقيقةً، وحذفٌ يعتمد
--  على مطابقة نصٍّ يمحو الحقيقيَّ يوم يتشابه الاسمان.
--
--  بل بالبنية: `app_users.auth_user_id` **يبقى فارغاً في بيانات البذرة**
--  ويُملأ عند تسجيل مستخدمٍ حقيقيّ من التطبيق. فهذا هو الفاصل، وهو مكتوبٌ في
--  المخطط منذ أوّل يوم لا مخترَعٌ الآن.
--
--  فمن سجّل نفسه من التطبيق — ولو بالأمس — يبقى هو وحجوزاته ومدفوعاته.
--
--  ────────────────────────────────────────────────────────────────────────────
--  ما يُحذف:
--    · العملاء التجريبيون وكل ما يتبعهم — أجهزتهم وجلساتهم وخططهم
--    · مقدّمو الخدمة التجريبيون وخدماتهم ومستنداتهم واشتراكاتهم
--    · الحجوزات والمدفوعات والتسويات والتقييمات والنزاعات والمحادثات
--    · الحملات الترويجية، والمقاييس اليومية، والإشعارات، وإصدارات التطبيق
--
--  ما **يبقى** — وهو مقصودٌ لا منسيّ:
--    · المحافظات وأقسام الخدمات — مرجعٌ يحتاجه التطبيق ليعمل، لا بيانات عرض
--    · باقات الاشتراك وسياسات الإلغاء — إعداداتُك أنت، وقد عدّلتَها بيدك
--    · المسؤولون ودعواتهم وإعدادات المنصة
--    · سجل العمليات — وله زرُّ تفريغٍ خاصٌّ به في صفحة السجل
--    · أي مستخدمٍ أو مقدّم خدمةٍ سجّل نفسه فعلاً من التطبيق
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- ١. قبل: ماذا في القاعدة الآن؟
-- ────────────────────────────────────────────────────────────────────────────
select 'قبل الحذف' as المرحلة,
       (select count(*) from public.app_users)         as العملاء,
       (select count(*) from public.service_providers) as المزودون,
       (select count(*) from public.bookings)          as الحجوزات,
       (select count(*) from public.payments)          as المدفوعات;

-- ────────────────────────────────────────────────────────────────────────────
-- ٢. من هم التجريبيون؟
--
--    الشرط مكرَّرٌ في كل جملة، ولا جداولَ مؤقّتة. وقد بدأتُ بها فأخفقت: محرّر
--    Supabase يُثبت كل جملةٍ على حدة، و`on commit drop` يحذف الجدول المؤقّت في
--    اللحظة التي يُنشأ فيها — فلا تجده الجملةُ التالية.
--
--    والتكرار آمنٌ هنا لأن الترتيب يحفظه: الأب لا يُحذف إلا بعد أبنائه كلّهم،
--    فيبقى الشرط الذي يقرأ منه صحيحاً إلى آخر جملةٍ تحتاجه. ولو عُكس الترتيب
--    لتغيّر معنى الشرط في منتصف العمل — وهو ما احترستُ منه بالجداول المؤقّتة
--    أوّلاً، ثم بالترتيب وحده.
-- ────────────────────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────────────────────
-- ٣. الحذف — من الورقة إلى الجذر.
--
--    الترتيب ليس تجميلاً: حذفُ الأب قبل ابنه يرفضه مفتاحٌ أجنبيّ، وحذفُ
--    الابن بعد أن مُحي أبوه بالتسلسل لا يجد ما يحذفه. فالورقة أوّلاً.
-- ────────────────────────────────────────────────────────────────────────────

-- المال: البنود قبل التسويات، والمدفوعات قبل الحجوزات
delete from public.settlement_items where settlement_id in (
  select id from public.settlements where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null)));
delete from public.settlements where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));

delete from public.payments where booking_id in (
  select id from public.bookings
   where user_id in (select id from public.app_users where auth_user_id is null)
      or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null)));

-- الثقة والتواصل
delete from public.dispute_messages where dispute_id in (
  select id from public.disputes where booking_id in (
    select id from public.bookings
     where user_id in (select id from public.app_users where auth_user_id is null)
        or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null))));
delete from public.disputes where booking_id in (
  select id from public.bookings
   where user_id in (select id from public.app_users where auth_user_id is null)
      or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null)));

delete from public.conversation_messages where conversation_id in (
  select id from public.conversations
   where user_id in (select id from public.app_users where auth_user_id is null)
      or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null)));
delete from public.conversations
 where user_id in (select id from public.app_users where auth_user_id is null)
    or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));

delete from public.reviews
 where user_id in (select id from public.app_users where auth_user_id is null)
    or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));

-- الحجوزات بعد أن خلت ممّا يعلّق بها
delete from public.bookings
 where user_id in (select id from public.app_users where auth_user_id is null)
    or provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));

-- ما يتبع مقدّم الخدمة
delete from public.provider_subscriptions where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));
delete from public.provider_availability   where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));
delete from public.provider_services       where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));
delete from public.provider_documents      where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));
delete from public.provider_categories     where provider_id in (select id from public.service_providers
             where user_id is null
                or user_id in (select id from public.app_users where auth_user_id is null));
delete from public.service_providers
 where user_id is null
    or user_id in (select id from public.app_users where auth_user_id is null);

-- ما يتبع العميل
delete from public.favourites     where user_id in (select id from public.app_users where auth_user_id is null);
delete from public.wedding_plans  where user_id in (select id from public.app_users where auth_user_id is null);
delete from public.user_devices   where user_id in (select id from public.app_users where auth_user_id is null);
delete from public.user_sessions  where user_id in (select id from public.app_users where auth_user_id is null);
delete from public.app_users where auth_user_id is null;

-- محتوىً تجريبيٌّ قائمٌ بذاته لا يتبع أحداً
delete from public.promotions        where id is not null;
delete from public.daily_metrics     where day is not null;
delete from public.push_notifications where id is not null;
delete from public.app_versions      where id is not null;

-- ────────────────────────────────────────────────────────────────────────────
-- ٤. بعد
--
--    جملةٌ واحدة تجمع المحذوف والباقي: محرّر Supabase لا يعرض إلا نتيجة آخر
--    جملة، فجدولان يعني أن أوّلهما يُكتب ثم يُحجب عن عين من شغّل السكربت.
-- ────────────────────────────────────────────────────────────────────────────
select 'بعد الحذف' as المرحلة,
       (select count(*) from public.app_users)          as العملاء,
       (select count(*) from public.service_providers)  as المزودون,
       (select count(*) from public.bookings)           as الحجوزات,
       (select count(*) from public.payments)           as المدفوعات,
       '—'                                              as ــ,
       (select count(*) from public.governorates)       as المحافظات,
       (select count(*) from public.service_categories) as الأقسام,
       (select count(*) from public.subscription_plans) as الباقات,
       (select count(*) from public.admins)             as المسؤولون;
