-- ============================================================================
--  الحضور: «متّصل الآن» و«آخر ظهور»
-- ============================================================================
--
--  ── علّةٌ كانت قائمةً منذ أوّل مخطَّط ──────────────────────────────────────
--
--  `app_users.last_seen_at` عمودٌ معرَّفٌ منذ أوّل يوم، **ولا سطرَ في التطبيق
--  كلِّه يكتبه**. واللوحةُ تقرؤه في ثلاثة مواضع:
--
--    • «آخر ظهور» في صفحة المستخدم        — فارغةٌ دائماً
--    • عمودُ «آخر ظهور» في قائمة المستخدمين — فارغ
--    • استهدافُ البثّ «نشِط» / «غير نشِط»   — والأسوأ
--
--  فالثالثُ ليس فراغاً بل خطأ: شرطُ «غير نشِط» هو `last_seen_at is null or
--  last_seen_at < now() - 30 days`، وعمودٌ فارغٌ لكلِّ مستخدمٍ يعني أنّ حملةً
--  تُبعث إلى «غير النشطين» تذهب إلى **الجميع**، وحملةً تُبعث إلى «النشطين»
--  لا تذهب إلى أحد. وكلاهما يقع صامتاً بلا خطأٍ يظهر.
--
--  فهنا تُكتب النبضة، ويُقرأ الحضور.
--
--  ── ولماذا نبضةٌ لا Realtime Presence ────────────────────────────────────
--
--  قناةُ الحضور في Realtime تعرف من هو في التطبيق **الآن** وتنسى من خرج.
--  و«آخر ظهور منذ ساعتين» — وهو أكثرُ ما يُقرأ — لا تعرفه القناة، ولا تملأ
--  عمودَ اللوحة، ولا تُصلح استهدافَ البثّ. والنبضةُ تفعل الثلاثة بجدولٍ قائم.
--
--  التشغيل:  psql "$DATABASE_URL" -f supabase/presence.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
--  النبضة — يكتبها التطبيق كلَّ دقيقةٍ وهو أمام صاحبه
-- ----------------------------------------------------------------------------
--
--  `security definer` لا لتجاوزِ شيء، بل لأنّ الكتابةَ محصورةٌ في صفِّ المنادي
--  وحدَه بشرطِ `current_app_user()` — فلا تحتاج سياسةَ تحديثٍ عامّةً على
--  `app_users` تفتح البابَ لأعمدةٍ أخرى.
--
--  ولا تُعيد شيئاً: يُنادى عليها كثيراً، فأرخصُ ردٍّ لا ردّ.
create or replace function public.api_touch_presence()
returns void
language sql security definer set search_path = public as $$
  update public.app_users
     set last_seen_at = now()
   where id = public.current_app_user()
$$;

grant execute on function public.api_touch_presence() to authenticated;

-- ----------------------------------------------------------------------------
--  حضورُ الطرف الآخر في محادثة
-- ----------------------------------------------------------------------------
--
--  والعضويّةُ شرطٌ هنا لا في الشاشة: من مرّر معرّفَ محادثةٍ ليس طرفاً فيها
--  يأخذ `null` لا طابعَ غيره الزمنيّ.
--
--  والطرفُ الآخر يُقلب بحسب من يسأل: العميلُ يسأل عن صاحب القاعة، وصاحبُ
--  القاعة يسأل عن العميل.
create or replace function public.api_conversation_presence(p_conversation_id uuid)
returns timestamptz
language plpgsql stable security definer set search_path = public as $$
declare
  me   uuid := public.current_app_user();
  mine uuid := public.current_provider();
  c    public.conversations%rowtype;
begin
  select * into c from public.conversations where id = p_conversation_id;
  if not found then return null; end if;

  if c.user_id is not null and c.user_id = me then
    return (select u.last_seen_at
              from public.service_providers p
              join public.app_users u on u.id = p.user_id
             where p.id = c.provider_id);
  end if;

  if c.provider_id is not null and c.provider_id = mine then
    return (select last_seen_at from public.app_users where id = c.user_id);
  end if;

  return null;
end $$;

grant execute on function public.api_conversation_presence(uuid) to authenticated;

-- ----------------------------------------------------------------------------
--  حضورُ مزوّدٍ في ملفّه العامّ
-- ----------------------------------------------------------------------------
--
--  والموثَّقُ وحدَه: غيرُ الموثَّق لا يظهر ملفُّه العامُّ أصلاً، فلا معنى
--  لأن يُسأل عن حضوره.
--
--  ودالّةٌ منفصلةٌ لا عمودٌ يُضاف إلى `v_providers`: تلك الطريقةُ
--  `security_invoker`، فلو انضمّت إلى `app_users` لَعادت فارغةً — لا سياسةَ
--  تسمح لعميلٍ بقراءة صفِّ مستخدمٍ آخر. ثمّ إنّ `api_providers_nearby` تُعيد
--  `setof v_providers`، فتغييرُ أعمدتها يجرّ إسقاطَ الدالّة معها.
create or replace function public.api_provider_presence(p_provider_id uuid)
returns timestamptz
language sql stable security definer set search_path = public as $$
  select u.last_seen_at
    from public.service_providers p
    join public.app_users u on u.id = p.user_id
   where p.id = p_provider_id
     and p.status = 'verified'
$$;

grant execute on function public.api_provider_presence(uuid) to anon, authenticated;

commit;

-- ----------------------------------------------------------------------------
--  تحقّق
-- ----------------------------------------------------------------------------
select 'نبضةُ الحضور' as البند,
       coalesce((select 'موجودة' from pg_proc where proname = 'api_touch_presence'),
                'غير موجودة') as القيمة
union all
select 'حضورُ المحادثة',
       coalesce((select 'موجودة' from pg_proc where proname = 'api_conversation_presence'),
                'غير موجودة')
union all
select 'حضورُ المزوّد',
       coalesce((select 'موجودة' from pg_proc where proname = 'api_provider_presence'),
                'غير موجودة')
union all
select 'مستخدمون لهم ظهورٌ مسجَّل',
       (select count(*)::text from public.app_users where last_seen_at is not null);
