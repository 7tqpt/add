-- ============================================================================
--  أعمدةُ مقدّم الخدمة — ما يراه العامّة وما لا يراه
--
--  شغّله **بعد `install.sql` و`apply.sql`**، وبعد ملفّات الأعمدة المضافة
--  (`provider_logo.sql` و`profile_cover.sql` و`nearby.sql`) إن شغّلتها.
--  وآمنٌ عند التكرار، وآمنٌ إن لم تُشغَّل تلك: ما لا عمودَ له لا يُمنح.
-- ============================================================================
--
--  ── الثغرةُ التي يغلقها ────────────────────────────────────────────────────
--
--  `providers_public_read` في `policies.sql` تفتح `service_providers` لـ
--  `anon` على كلّ صفٍّ حالتُه `verified`. **وRLS تحجب صفوفاً لا أعمدة** — فمن
--  ملك المفتاحَ العامّ (وهو في كلّ حزمة أندرويد، يُستخرج في دقائق) قرأ بنداءٍ
--  واحد: بريدَ كلِّ مقدّم خدمةٍ موثَّقٍ ورقمَه، وكم كسب، وعمولتَه الخاصّة،
--  وسببَ رفضه إن رُفض ثمّ وُثّق.
--
--  **والنيّةُ كانت في الشجرة مكتوبةً**: العرضُ `v_providers` يعدّ أعمدتَه
--  واحداً واحداً ويستثني هذه الخمسةَ بالضبط. لكنّ `grant select on all tables`
--  في `schema.sql` يلتفّ عليه: من قرأ الجدولَ لم يمرّ بالعرض.
--
--  وهو النمطُ نفسُه الذي في `availability.sql` للملاحظة — كُتب هناك ولم
--  يُعمَّم، لأنّ ثمانيةً وستّين اختباراً تسأل عن الصفوف ولا واحدٌ منها يسأل
--  عن الأعمدة. فيُكتب هنا، ويُقاس في `tests/column_privileges.test.mjs`.
--
--  ── وثلاثةُ أبوابٍ تبقى مفتوحةً لأهلها ────────────────────────────────────
--
--    · **صاحبُ الملفّ** يقرأ صفَّه كاملاً بـ`api_my_provider()` — دالّةٌ
--      `security definer` حدُّها `current_provider()`، فلا تُخرج صفَّ غيره.
--    · **المسؤول** يقرأ الجدولَ كلَّه بـ`v_admin_providers` — وقد صارت
--      `security definer` وفيها `where public.is_admin()`، فتردّ صفراً لمن
--      ليس مسؤولاً. (وكانت `security_invoker` فتتبع صلاحيةَ السائل — وهي
--      اليوم تعني: لا شيء.)
--    · **العامّةُ** يقرؤون `v_providers` كما كانوا. وهي `security_invoker`
--      وأعمدتُها كلُّها من المسموح أدناه، فلا تتغيّر.
--
--  ── ولماذا قائمةُ المسموح لا قائمةُ الممنوع ───────────────────────────────
--
--  «امنح كلَّ شيءٍ إلّا الخمسة» يعني أنّ عموداً يُضاف غداً يخرج **مكشوفاً**
--  حتى ينتبه أحد — وهذا هو بعينه ما أوقعنا فيما نحن فيه. فتُسمّى المسموحة،
--  وما جاء بعدها فمحجوبٌ حتى يُذكر هنا بيدٍ. ويُعلَن اسمُه وقت التشغيل كي لا
--  يبقى محجوباً بصمتٍ فيُظنّ عطباً في التطبيق.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. صفّي أنا — لصاحب الملفّ وحدَه
--
-- `returns setof public.service_providers` لا قائمةَ أعمدةٍ مكتوبة: القاعدةُ
-- قد ينقصها `cover_path` أو `latitude`، وقائمةٌ مكتوبةٌ هنا تُحمِّر الملفَّ
-- كلَّه عند من لم يشغّل `profile_cover.sql`. و`setof <جدول>` تُعيد ما في
-- الجدول أيّاً كان — فتنمو معه بلا تعديل.
--
-- **و`security definer` هنا ليست تساهلاً**: حدُّها سطرٌ واحد
-- (`id = current_provider()`)، و`current_provider()` تُشتقّ من `auth.uid()`
-- لا ممّا يرسله التطبيق. فلا معرّفَ يُمرَّر ولا صفَّ غيرِ صاحبه يُقرأ.
-- ----------------------------------------------------------------------------
create or replace function public.api_my_provider()
returns setof public.service_providers
language sql
stable
security definer
set search_path = public
as $$
  select * from public.service_providers where id = public.current_provider()
$$;

comment on function public.api_my_provider() is
  'صفُّ مقدّم الخدمة كاملاً لصاحبه وحدَه — بالأرباح وسبب الرفض. ولا معرّفَ لها: الحدُّ من الجلسة.';

revoke all on function public.api_my_provider() from public, anon;
grant execute on function public.api_my_provider() to authenticated;

-- ----------------------------------------------------------------------------
-- ٢. والمسؤولُ يقرأ الجدولَ كلَّه — وهو وحدَه
--
-- **وهذه تُعاد هنا كما هي في `apply.sql`** بعد تعديلها هناك. والتكرارُ مقصود:
-- من شغّل `apply.sql` قبل هذا الملفّ عنده النسخةُ القديمة، ومن أعاد تشغيلَه
-- بعده يجدها مصحَّحةً في الملفّين معاً. ولو كُتبت في موضعٍ واحدٍ لَكسرت
-- إعادةُ تشغيلِ أحدِهما عملَ الآخر.
--
-- و`drop … create` لا `create or replace`: الأخيرةُ ترفض تبديلَ قائمة
-- الأعمدة، و`p.*` تكتسب عموداً كلّما أُضيف إلى جدولها.
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_providers;
create view public.v_admin_providers as
select
  p.*,
  coalesce(
    (select array_agg(c.name order by c.sort_order)
       from public.provider_categories pc
       join public.service_categories c on c.id = pc.category_id
      where pc.provider_id = p.id),
    '{}'::text[]
  ) as categories
from public.service_providers p
where public.is_admin();

grant select on public.v_admin_providers to authenticated;

-- ----------------------------------------------------------------------------
-- ٣. ونزعُ الأعمدة — وهو المقصودُ كلُّه
--
-- **يُنزع المنحُ العامُّ أوّلاً ثمّ يُعاد على الأعمدة المسمّاة.** ولا يكفي
-- منحُ الأعمدة وحدَه: منحٌ على الجدول كلِّه ومنحٌ على أعمدةٍ منه يجتمعان، ولا
-- يُضيّق الثاني الأوّل.
-- ----------------------------------------------------------------------------
do $$
declare
  -- ما يراه العامّة. وكلُّه معروضٌ في التطبيق أصلاً أو لازمٌ لعرضه.
  allowed text[] := array[
    'id', 'user_id', 'full_name', 'business_name', 'bio',
    'logo_path', 'cover_path',
    'governorate_id', 'governorate', 'coverage_areas',
    'status', 'is_featured',
    'rating', 'reviews_count', 'completed_bookings',
    'applied_at', 'verified_at', 'created_at',
    'latitude', 'longitude'
  ];
  -- وما لا يُرى. ويُسمّى صراحةً — لا ليُحجَب (حجبُه أنّه ليس أعلاه) بل
  -- ليُقرأ: من فتح الملفَّ يعرف **ما** يحرسه لا أنّ ثَمَّ حرزاً.
  secret text[] := array[
    'email', 'phone', 'total_earnings', 'commission_percent', 'rejection_reason'
  ];
  present text[];
  unknown text[];
  granted text;
begin
  select array_agg(column_name::text order by ordinal_position)
    into present
    from information_schema.columns
   where table_schema = 'public' and table_name = 'service_providers';

  if present is null then
    raise exception 'لا جدولَ public.service_providers — شغّل install.sql أوّلاً.';
  end if;

  -- **ولا يُمنح عمودٌ لا وجودَ له**: قاعدةٌ لم يُشغَّل عليها `nearby.sql`
  -- ليس فيها `latitude`، ومنحٌ عليه يُسقط الملفَّ كلَّه برسالةٍ عن عمودٍ
  -- لا يعرفه أحد.
  select string_agg(quote_ident(c), ', ' order by c)
    into granted
    from unnest(present) c
   where c = any(allowed);

  execute 'revoke select on public.service_providers from anon, authenticated';
  execute format(
    'grant select (%s) on public.service_providers to anon, authenticated', granted);

  -- **وعمودٌ لا في هذه ولا في تلك يُعلَن.** وإلّا خرج محجوباً بصمت، فبحث
  -- من أضافه عن العلّة في التطبيق وهي هنا.
  select array_agg(c order by c) into unknown
    from unnest(present) c
   where not (c = any(allowed)) and not (c = any(secret));

  if unknown is not null then
    raise warning
      'أعمدةٌ في service_providers ليست في قائمة المسموح ولا الممنوع، فهي محجوبةٌ عن التطبيق: %. أضفها إلى provider_columns.sql.',
      array_to_string(unknown, ', ');
  end if;
end $$;

-- والكتابةُ كما كانت: هذا نزعُ قراءةٍ لا نزعُ تعديل. واللوحةُ توثّق وترفض
-- وتضبط العمولة، والمزوّدُ يعدّل ملفَّه — وكلُّه `update` تحرسه RLS.
grant insert, update, delete on public.service_providers to authenticated;

commit;

-- ----------------------------------------------------------------------------
-- للتحقّق بعد التشغيل — ويجب أن تخرج الخمسةُ كلُّها `false`
-- ----------------------------------------------------------------------------
--   select c.column_name,
--          has_column_privilege('anon', 'public.service_providers', c.column_name, 'select')
--     from information_schema.columns c
--    where c.table_schema = 'public' and c.table_name = 'service_providers'
--      and c.column_name in
--          ('email','phone','total_earnings','commission_percent','rejection_reason');

notify pgrst, 'reload schema';
