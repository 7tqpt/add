-- ============================================================================
--  سياسات الوصول (RLS) — شغّلها بعد schema.sql
--
--  التطبيقان يتصلان بقاعدة البيانات مباشرة عبر Supabase، فهذا الملف هو جدار
--  الحماية الفعلي: هو ما يمنع عميلاً من رؤية حجز عميل آخر، ومقدّم خدمة من
--  تعديل خدمات غيره. لا تعتمد على تصفية في التطبيق — التطبيق يمكن تعديله.
--
--  أربعة أطراف:
--    anon          الزائر قبل تسجيل الدخول — يرى المعروض للعامة فقط
--    العميل        يرى ويعدّل بياناته هو
--    مقدّم الخدمة   يدير خدماته وحجوزاته هو
--    المسؤول       يرى كل شيء؛ والكتابة لمن دوره owner أو admin
--
--  لوحة التحكم للمسؤولين وحدهم — لا يصلها عميل ولا مقدّم خدمة.
-- ============================================================================

-- ============================================================================
--  1. المرجعيات — يقرؤها الجميع حتى قبل تسجيل الدخول
--     (التطبيق يعرض الأقسام والمحافظات في أول شاشة)
-- ============================================================================

drop policy if exists governorates_public_read on public.governorates;
create policy governorates_public_read on public.governorates
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists governorates_admin_write on public.governorates;
create policy governorates_admin_write on public.governorates
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists categories_public_read on public.service_categories;
create policy categories_public_read on public.service_categories
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists categories_admin_write on public.service_categories;
create policy categories_admin_write on public.service_categories
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- سياسة الإلغاء يجب أن يراها العميل قبل الحجز، كما تنص الوثيقة
drop policy if exists policies_public_read on public.cancellation_policies;
create policy policies_public_read on public.cancellation_policies
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists policies_admin_write on public.cancellation_policies;
create policy policies_admin_write on public.cancellation_policies
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists plans_public_read on public.subscription_plans;
create policy plans_public_read on public.subscription_plans
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists plans_admin_write on public.subscription_plans;
create policy plans_admin_write on public.subscription_plans
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الإعدادات: التطبيق يحتاج وضع الصيانة وأدنى إصدار مدعوم قبل الدخول
drop policy if exists settings_public_read on public.app_settings;
create policy settings_public_read on public.app_settings
  for select to anon, authenticated using (true);

drop policy if exists settings_admin_write on public.app_settings;
create policy settings_admin_write on public.app_settings
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists versions_public_read on public.app_versions;
create policy versions_public_read on public.app_versions
  for select to anon, authenticated using (true);

drop policy if exists versions_admin_write on public.app_versions;
create policy versions_admin_write on public.app_versions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  2. الحسابات
-- ============================================================================

-- العميل يرى ويعدّل حسابه هو. لا يرى حسابات غيره إطلاقاً.
drop policy if exists users_self_read on public.app_users;
create policy users_self_read on public.app_users
  for select to authenticated
  using (auth_user_id = auth.uid() or public.is_admin());

drop policy if exists users_self_update on public.app_users;
create policy users_self_update on public.app_users
  for update to authenticated
  using (auth_user_id = auth.uid())
  -- الحالة والصلاحيات ليست للمستخدم؛ تُغيَّر من اللوحة أو من دوال الـ API
  with check (auth_user_id = auth.uid());

drop policy if exists users_self_insert on public.app_users;
create policy users_self_insert on public.app_users
  for insert to authenticated with check (auth_user_id = auth.uid());

drop policy if exists users_admin_write on public.app_users;
create policy users_admin_write on public.app_users
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الجلسات والأجهزة: يكتبها التطبيق لحساب صاحبها، ويقرؤها هو والمسؤول.
drop policy if exists sessions_owner on public.user_sessions;
create policy sessions_owner on public.user_sessions
  for select to authenticated
  using (user_id = public.current_app_user() or public.is_admin());

drop policy if exists sessions_owner_insert on public.user_sessions;
create policy sessions_owner_insert on public.user_sessions
  for insert to authenticated with check (user_id = public.current_app_user());

drop policy if exists devices_owner on public.user_devices;
create policy devices_owner on public.user_devices
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user() or public.can_write());

-- ============================================================================
--  3. مقدّمو الخدمة
-- ============================================================================

-- الموثّقون فقط ظاهرون للعامة؛ ومقدّم الخدمة يرى ملفه مهما كانت حالته.
drop policy if exists providers_public_read on public.service_providers;
create policy providers_public_read on public.service_providers
  for select to anon, authenticated
  using (
    status = 'verified'
    or user_id = public.current_app_user()
    or public.is_admin()
  );

-- يعدّل ملفه هو. تغيير الحالة إلى «موثّق» ليس بيده — انظر شرط with check.
drop policy if exists providers_self_update on public.service_providers;
create policy providers_self_update on public.service_providers
  for update to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

drop policy if exists providers_admin_write on public.service_providers;
create policy providers_admin_write on public.service_providers
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- منع مقدّم الخدمة من ترقية نفسه: أي تغيير على الحالة أو التوثيق أو العمولة
-- يجب أن يأتي من الإدارة. مشغّل لأن RLS لا يقارن الصف قبل التعديل وبعده.
create or replace function public.guard_provider_self_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- المسؤول، أو دالة API داخلية رفعت العلم أدناه (تحديث العدّادات والتقييم بعد
  -- إتمام حجز). العلم محلّي المعاملة، فلا يتسرّب إلى طلب آخر.
  if public.is_admin()
     or coalesce(current_setting('app.internal', true), '') = 'on' then
    return new;
  end if;

  if new.status is distinct from old.status
     or new.verified_at is distinct from old.verified_at
     or new.is_featured is distinct from old.is_featured
     or new.commission_percent is distinct from old.commission_percent
     or new.rating is distinct from old.rating
     or new.reviews_count is distinct from old.reviews_count
     or new.total_earnings is distinct from old.total_earnings then
    raise exception 'هذه الحقول تُعدَّل من إدارة المنصة فقط';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_provider_self_update on public.service_providers;
create trigger guard_provider_self_update
  before update on public.service_providers
  for each row execute function public.guard_provider_self_update();

-- أقسام مقدّم الخدمة: ظاهرة للعامة، يديرها صاحبها.
drop policy if exists provider_categories_read on public.provider_categories;
create policy provider_categories_read on public.provider_categories
  for select to anon, authenticated using (true);

drop policy if exists provider_categories_owner on public.provider_categories;
create policy provider_categories_owner on public.provider_categories
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- المستندات: خاصة تماماً — صاحبها والإدارة فقط. لا تُعرض للعامة أبداً.
drop policy if exists documents_owner_read on public.provider_documents;
create policy documents_owner_read on public.provider_documents
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists documents_owner_upload on public.provider_documents;
create policy documents_owner_upload on public.provider_documents
  for insert to authenticated with check (provider_id = public.current_provider());

-- المراجعة (قبول/رفض) للإدارة وحدها
drop policy if exists documents_admin_write on public.provider_documents;
create policy documents_admin_write on public.provider_documents
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الخدمات: يراها الجميع إن كانت مفعّلة ومقدّمها موثّق.
drop policy if exists services_public_read on public.provider_services;
create policy services_public_read on public.provider_services
  for select to anon, authenticated
  using (
    (is_active and exists (
      select 1 from public.service_providers p
      where p.id = provider_id and p.status = 'verified'
    ))
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists services_owner_write on public.provider_services;
create policy services_owner_write on public.provider_services
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- التقويم: يقرؤه الجميع (العميل يحتاج معرفة الأيام المشغولة)، ويديره صاحبه.
drop policy if exists availability_public_read on public.provider_availability;
create policy availability_public_read on public.provider_availability
  for select to anon, authenticated using (true);

drop policy if exists availability_owner_write on public.provider_availability;
create policy availability_owner_write on public.provider_availability
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- ============================================================================
--  4. خطط الأعراس والحجوزات
-- ============================================================================

-- خطة العرس خاصة بصاحبها وحده. مقدّم الخدمة لا يراها.
drop policy if exists plans_owner on public.wedding_plans;
create policy plans_owner on public.wedding_plans
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user() or public.can_write());

-- الحجز يراه طرفاه فقط: العميل صاحبه، ومقدّم الخدمة المعني.
drop policy if exists bookings_parties_read on public.bookings;
create policy bookings_parties_read on public.bookings
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- الإنشاء والانتقالات تمرّ عبر دوال الـ API (api.sql) لا بكتابة مباشرة، لأن
-- السعر والعمولة والعربون تُحسب في الخادم — لا يملي العميل ما سيدفعه.
drop policy if exists bookings_admin_write on public.bookings;
create policy bookings_admin_write on public.bookings
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists favourites_owner on public.favourites;
create policy favourites_owner on public.favourites
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user());

-- ============================================================================
--  5. المالية
-- ============================================================================

-- المدفوعات: يقرؤها طرفاها. لا يكتبها أحد من التطبيق — تُنشأ من دوال الـ API
-- ومن خطّاف بوابة الدفع بمفتاح الخدمة.
drop policy if exists payments_parties_read on public.payments;
create policy payments_parties_read on public.payments
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists payments_admin_write on public.payments;
create policy payments_admin_write on public.payments
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists invoices_parties_read on public.invoices;
create policy invoices_parties_read on public.invoices
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists invoices_admin_write on public.invoices;
create policy invoices_admin_write on public.invoices
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- التسويات: مقدّم الخدمة يرى مستحقاته، ولا يعدّلها.
drop policy if exists settlements_owner_read on public.settlements;
create policy settlements_owner_read on public.settlements
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists settlements_admin_write on public.settlements;
create policy settlements_admin_write on public.settlements
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists settlement_items_owner_read on public.settlement_items;
create policy settlement_items_owner_read on public.settlement_items
  for select to authenticated
  using (
    exists (
      select 1 from public.settlements s
      where s.id = settlement_id
        and (s.provider_id = public.current_provider() or public.is_admin())
    )
  );

drop policy if exists settlement_items_admin_write on public.settlement_items;
create policy settlement_items_admin_write on public.settlement_items
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  6. الثقة: التقييمات والنزاعات والمحادثات
-- ============================================================================

-- التقييمات المنشورة يراها الجميع — هي أساس ثقة العميل بمقدّم الخدمة.
-- المخفية والمُبلَّغ عنها يراها صاحبها والإدارة فقط.
drop policy if exists reviews_public_read on public.reviews;
create policy reviews_public_read on public.reviews
  for select to anon, authenticated
  using (
    status = 'published'
    or user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- الكتابة عبر api_submit_review فقط: هي التي تتحقّق أن الحجز نُفّذ فعلاً.
drop policy if exists reviews_admin_write on public.reviews;
create policy reviews_admin_write on public.reviews
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists disputes_parties_read on public.disputes;
create policy disputes_parties_read on public.disputes
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists disputes_admin_write on public.disputes;
create policy disputes_admin_write on public.disputes
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists dispute_messages_parties on public.dispute_messages;
create policy dispute_messages_parties on public.dispute_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.disputes d
      where d.id = dispute_id
        and (d.user_id = public.current_app_user()
             or d.provider_id = public.current_provider()
             or public.is_admin())
    )
  );

drop policy if exists dispute_messages_write on public.dispute_messages;
create policy dispute_messages_write on public.dispute_messages
  for insert to authenticated
  with check (
    public.can_write()
    or exists (
      select 1 from public.disputes d
      where d.id = dispute_id
        and ((d.user_id = public.current_app_user() and author = 'customer')
             or (d.provider_id = public.current_provider() and author = 'provider'))
    )
  );

-- المحادثات: طرفاها فقط. الإدارة تقرأ عند النظر في نزاع، ولا تكتب فيها.
drop policy if exists conversations_parties on public.conversations;
create policy conversations_parties on public.conversations
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists conversations_parties_write on public.conversations;
create policy conversations_parties_write on public.conversations
  for insert to authenticated
  with check (user_id = public.current_app_user() or provider_id = public.current_provider());

drop policy if exists conversation_messages_parties on public.conversation_messages;
create policy conversation_messages_parties on public.conversation_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.user_id = public.current_app_user()
             or c.provider_id = public.current_provider()
             or public.is_admin())
    )
  );

drop policy if exists conversation_messages_send on public.conversation_messages;
create policy conversation_messages_send on public.conversation_messages
  for insert to authenticated
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and ((c.user_id = public.current_app_user() and sender = 'customer')
             or (c.provider_id = public.current_provider() and sender = 'provider'))
    )
  );

-- ============================================================================
--  7. الاشتراكات والإعلانات والإشعارات
-- ============================================================================

drop policy if exists subscriptions_owner_read on public.provider_subscriptions;
create policy subscriptions_owner_read on public.provider_subscriptions
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists subscriptions_admin_write on public.provider_subscriptions;
create policy subscriptions_admin_write on public.provider_subscriptions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الإعلانات النشطة يراها التطبيق ليعرضها؛ وصاحبها يرى إحصاءاته.
drop policy if exists promotions_public_read on public.promotions;
create policy promotions_public_read on public.promotions
  for select to anon, authenticated
  using (
    (status = 'active' and now() between starts_at and ends_at)
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists promotions_admin_write on public.promotions;
create policy promotions_admin_write on public.promotions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- صندوق الإشعارات: صاحبه فقط، وله أن يعلّمها مقروءة.
drop policy if exists notifications_owner_read on public.notifications;
create policy notifications_owner_read on public.notifications
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists notifications_owner_update on public.notifications;
create policy notifications_owner_update on public.notifications
  for update to authenticated
  using (user_id = public.current_app_user() or provider_id = public.current_provider())
  with check (user_id = public.current_app_user() or provider_id = public.current_provider());

drop policy if exists notifications_admin_write on public.notifications;
create policy notifications_admin_write on public.notifications
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  8. ما لا يخرج من اللوحة إطلاقاً
-- ============================================================================

-- حملات الإشعارات، المقاييس، وسجل المسؤولين: لا يراها مستخدم ولا مقدّم خدمة.
drop policy if exists push_admin_only on public.push_notifications;
create policy push_admin_only on public.push_notifications
  for all to authenticated using (public.is_admin()) with check (public.can_write());

drop policy if exists metrics_admin_only on public.daily_metrics;
create policy metrics_admin_only on public.daily_metrics
  for all to authenticated using (public.is_admin()) with check (public.can_write());

-- جدول المسؤولين: يقرأه كل مسؤول، ولا يعدّله إلا المالك.
drop policy if exists admins_read on public.admins;
create policy admins_read on public.admins
  for select to authenticated using (public.is_admin());

drop policy if exists admins_owner_writes on public.admins;
create policy admins_owner_writes on public.admins
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- سجل العمليات: للإلحاق فقط — لا سياسة update ولا delete إطلاقاً، حتى لا يمحو
-- مسؤول أثر ما فعله.
drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log
  for select to authenticated using (public.is_admin());

drop policy if exists audit_log_append on public.audit_log;
create policy audit_log_append on public.audit_log
  for insert to authenticated with check (public.can_write());

-- ============================================================================
--  9. صلاحيات الجداول
--
--  RLS تقرّر أي صفوف يراها المتصل، لكن GRANT هي التي تسمح له بلمس الجدول أصلاً.
--  Supabase يمنح هذه تلقائياً عادةً، لكن تركها ضمنية يجعل المشروع يعمل عندك
--  ويفشل عند غيرك — فتُكتب صراحةً.
-- ============================================================================

grant usage on schema public to anon, authenticated;

grant select on all tables in schema public to anon, authenticated;
grant insert, update, delete on all tables in schema public to authenticated;

-- الجداول الجديدة لاحقاً ترث نفس المنح
alter default privileges in schema public
  grant select on tables to anon, authenticated;
alter default privileges in schema public
  grant insert, update, delete on tables to authenticated;
