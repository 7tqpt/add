-- ============================================================================
--  حذفُ الخدمة — ويُمنع ما دام عليها حجزٌ قادم
--
--  طلب صاحبُ المنصّة زرَّ حذفٍ في بطاقة الخدمة، واختار من اثنين: **(١) يُمنع
--  الحذفُ ما دام عليها حجزٌ قادم**.
--
--  ── ولماذا في القاعدة لا في الشاشة ─────────────────────────────────────────
--
--  سياسةُ `provider_services_owner` تسمح لصاحب الخدمة بالحذف مباشرةً — فحارسٌ
--  في `services.dart` يُتجاوَز بملفِّ APK مفكوك. **والحرزُ حيث لا يُتجاوَز.**
--
--  ── ولا تُرمى رسالةٌ عربيّةٌ من الخادم ──────────────────────────────────────
--
--  التطبيقُ بلغتين، والرسالةُ المرميّةُ من الخادم تصل كما هي فلا تُترجَم.
--  فتُعاد **حقيقةٌ لا عبارة**: تاريخُ الحجز المانع. والشاشةُ تصوغه بلغتها
--  وتنسّق تاريخَه بمنسّقها.
--
--  ── وما يُحذف معها ─────────────────────────────────────────────────────────
--
--  صفوفُ `service_media` تُحذف هنا، **وملفّاتُها في السلّة لا تحذفها قاعدةُ
--  البيانات**: تبقى تأكل المساحة ورابطُها يعمل. فتُعاد مساراتُها إلى الطالب
--  ليمحوها من السلّة — ولذلك تُعيد الدالّةُ صفّاً لا `void`.
--
--  والحجوزاتُ الماضيةُ تبقى: `bookings.service_id` مضبوطٌ على `set null`
--  و`service_title` منسوخٌ نصّاً وقتَ الحجز. فالسجلُّ لا ينقطع.
-- ============================================================================

-- الحالاتُ التي تعني «حجزٌ حيٌّ ينتظر».
--
-- **ولا تدخل فيها `completed`:** عرسٌ انتهى لا يمنع صاحبَه من ترتيب قائمته.
-- ولا `rejected` و`cancelled` و`expired`: تلك لا ينتظرها أحد.
create or replace function public.api_delete_service(p_service_id uuid)
returns table (deleted boolean, blocking_date date, paths text[])
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_provider();
  owner_id uuid;
  blocked  date;
  media    text[];
begin
  if me is null then
    raise exception 'لا ملفَّ مزوّدٍ لهذا الحساب.' using errcode = '42501';
  end if;

  select ps.provider_id into owner_id
    from public.provider_services ps where ps.id = p_service_id;

  if owner_id is null then
    raise exception 'الخدمة غير موجودة.' using errcode = 'P0002';
  end if;

  -- **ولا يُفرَّق بين «ليست لك» و«غير موجودة» في المعنى**، لكنّ الرمزَ يفترق
  -- ليُقاس: من يجرّب معرّفاتٍ عشوائيّةً لا يُفيده الفرقُ شيئاً.
  if owner_id <> me then
    raise exception 'الخدمة ليست لك.' using errcode = '42501';
  end if;

  select min(b.event_date) into blocked
    from public.bookings b
   where b.service_id = p_service_id
     and b.status in ('pending_provider', 'confirmed')
     and b.event_date >= current_date;

  if blocked is not null then
    return query select false, blocked, array[]::text[];
    return;
  end if;

  select coalesce(array_agg(m.path), array[]::text[]) into media
    from public.service_media m where m.service_id = p_service_id;

  delete from public.service_media where service_id = p_service_id;
  delete from public.provider_services where id = p_service_id;

  return query select true, null::date, media;
end;
$$;

revoke all on function public.api_delete_service(uuid) from public;
grant execute on function public.api_delete_service(uuid) to authenticated;

comment on function public.api_delete_service(uuid) is
  'يحذف خدمةَ صاحبها ووسائطَها، ويردّ الحذفَ ما دام عليها حجزٌ قادم. '
  'يعيد مسارات الوسائط لتُمحى من السلّة.';
