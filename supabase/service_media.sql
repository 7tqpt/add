-- ============================================================================
--  وسائط الخدمة: صورٌ ومقطع فيديو ومقطع صوتي
--
--  شغّله في محرّر SQL بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا:**
--
--  العميل يحجز قاعةً لم يرها، ومطبخاً لم يذق طعامه، وفرقةً لم يسمعها. وكل ما
--  كان أمامه سطرُ عنوانٍ وسعر. فمن يدفع عربوناً بثلاثمئة ألفٍ على وصفٍ في
--  سطرين إنما يقامر، ومن لا يقامر لا يحجز — فتقف المنصّة عند التصفّح.
--
--  فهذه ثلاثةٌ لكل خدمة: **صورٌ** تُري المكان، و**مقطع فيديو لدقيقة** يُري ما
--  لا تُريه صورةٌ ساكنة (القاعة وهي ممتلئة، الطبخ وهو يُقدَّم)، و**مقطع صوتي**
--  — وهذا الأخير لأجل الفنانين والفرق خاصةً: صورةُ مغنٍّ لا تقول شيئاً عن
--  صوته، وهو كلُّ ما يُشترى منه.
--
--  **ولماذا جدولٌ لا العمود `provider_services.images`:**
--
--  العمود `text[]` موجودٌ منذ أول مخطط ولم يُستعمل قط — ولو استُعمل لما كفى:
--  لا يحمل نوعاً (أصورةٌ هي أم فيديو؟)، ولا مدّةً تُقاس عليها الدقيقة، ولا
--  ترتيباً يختار صاحبُ الخدمة أيَّ صورةٍ تكون الأولى، ولا حجماً يُحاسب عليه.
--  ومصفوفةُ نصوصٍ لا يمكن أن تُحمَل عليها سياسةُ صفٍّ ولا قيدُ عدد. يُترك
--  العمود حيث هو — لا شيء يقرؤه — ويُبنى الجدول.
--
--  **وما لا تستطيعه القاعدة:**
--
--  حدُّ الدقيقة يُقاس في التطبيق قبل الرفع (‏`video_player` يفتح الملف ويقرأ
--  مدّته‏)، والقاعدة لا ترى الملف بل الرقم المصرَّح به. فالقيدُ هنا يمنع
--  **تسجيل** رقمٍ فوق الستّين، ولا يمنع رفعَ ملفٍ أطول بادّعاء رقمٍ أقصر.
--  والذي يمنع ذلك فعلاً هو حدُّ حجم الملف في السلّة — وهو مفروضٌ من التخزين
--  نفسه لا من عميلٍ يمكن تعديله. فالحدّان معاً: رقمٌ في القاعدة وحجمٌ في
--  السلّة.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ١. الجدول
--
--    `provider_id` مكرَّرٌ هنا عن قصد: سياسة السلّة تقارن أوّل جزءٍ من مسار
--    الملف بمعرّف المزوّد، وسياسة الصفّ تحتاجه بلا ضمٍّ في كل قراءة. والتكرار
--    لا يُترك للثقة — مفتاحٌ أجنبيٌّ مركّب على (service_id, provider_id) يجعل
--    القاعدة ترفض صفّاً نُسب فيه ملفٌ إلى خدمةٍ ليست لصاحبه.
-- ----------------------------------------------------------------------------

-- المفتاح المركّب يحتاج فهرساً فريداً يشير إليه.
create unique index if not exists provider_services_id_provider_key
  on public.provider_services (id, provider_id);

create table if not exists public.service_media (
  id               uuid primary key default gen_random_uuid(),
  service_id       uuid not null,
  provider_id      uuid not null,
  kind             text not null check (kind in ('image', 'video', 'audio')),
  -- المسار داخل السلّة لا الرابط: الرابط يحمل اسم المشروع ونطاقه، وتغيّرُهما
  -- يعني وسائطَ تختفي. والمسار ثابتٌ يُشتقّ منه رابطٌ جديد عند كل عرض.
  path             text not null unique,
  title            text not null default '',
  duration_seconds integer not null default 0 check (duration_seconds between 0 and 60),
  size_bytes       bigint not null default 0 check (size_bytes >= 0),
  sort_order       integer not null default 0,
  created_at       timestamptz not null default now(),

  constraint service_media_service_fkey
    foreign key (service_id, provider_id)
    references public.provider_services (id, provider_id) on delete cascade,

  -- صورةٌ بلا مدّة، ومقطعٌ بلا مدّة خطأ: «٠ ثانية» تحت مقطعٍ يعني أن القياس
  -- لم يقع، فيمرّ ملفٌ لم تُعرف مدّته قط.
  constraint service_media_still_has_no_duration
    check (kind <> 'image' or duration_seconds = 0),
  constraint service_media_clip_has_duration
    check (kind = 'image' or duration_seconds > 0)
);

create index if not exists service_media_service_idx
  on public.service_media (service_id, kind, sort_order);
create index if not exists service_media_provider_idx
  on public.service_media (provider_id);

-- ----------------------------------------------------------------------------
-- ٢. حدُّ العدد
--
--    ثماني صورٍ ومقطعٌ واحدٌ من كلٍّ. والحدّ ليس بخلاً بالمساحة وحده: شاشةُ
--    تفاصيلَ فيها أربعون صورة لا تُقرأ، ومن رفع أربعين لم يُرَ منه شيء.
--    ومقطعان لا معنى لهما — الثاني يُخفي الأوّل ولا أحد يمرّر بحثاً عنه.
--
--    وقيدُ `check` لا يعدّ صفوفاً، فالحارس مُشغِّل.
-- ----------------------------------------------------------------------------
create or replace function public.service_media_limit()
returns trigger language plpgsql as $$
declare
  cap   integer := case new.kind when 'image' then 8 else 1 end;
  taken integer;
begin
  select count(*) into taken
  from public.service_media
  where service_id = new.service_id and kind = new.kind and id <> new.id;

  if taken >= cap then
    raise exception using
      errcode = '23514',
      message = case new.kind
        when 'image' then 'بلغتَ الحدّ: ثماني صورٍ للخدمة الواحدة.'
        when 'video' then 'للخدمة مقطع فيديو واحد. احذف القديم قبل رفع غيره.'
        else 'للخدمة مقطع صوتي واحد. احذف القديم قبل رفع غيره.'
      end;
  end if;
  return new;
end $$;

drop trigger if exists service_media_limit on public.service_media;
create trigger service_media_limit
  before insert or update of kind, service_id on public.service_media
  for each row execute function public.service_media_limit();

-- ----------------------------------------------------------------------------
-- ٣. سياسات الصفّ
--
--    القراءة تتبع الخدمة نفسها لا تنفرد بحكم: خدمةٌ موقوفة أو مزوّدٌ غير
--    موثّق لا تُعرض في الاستكشاف، فلو انفتحت وسائطُها لكانت نافذةً إلى ما
--    أُغلق بابه.
-- ----------------------------------------------------------------------------
alter table public.service_media enable row level security;

drop policy if exists media_public_read on public.service_media;
create policy media_public_read on public.service_media
  for select to anon, authenticated
  using (
    exists (
      select 1
      from public.provider_services s
      join public.service_providers p on p.id = s.provider_id
      where s.id = service_id
        and (
          (s.is_active and p.status = 'verified')
          or s.provider_id = public.current_provider()
          or public.is_admin()
        )
    )
  );

drop policy if exists media_owner_write on public.service_media;
create policy media_owner_write on public.service_media
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- ----------------------------------------------------------------------------
-- ٤. السلّة
--
--    **عامة** — بخلاف `provider-docs`. تلك تحمل هويّاتٍ وسجلّاتٍ تجارية
--    فتُحرَس، وهذه ما يقصد صاحبُها أن يراه كلُّ من تصفّح. وجعلُها خاصةً يعني
--    رابطاً موقّتاً لكل صورةٍ في كل بطاقةٍ في كل قائمة.
--
--    والحدّ ‎٥٠‎ ميجابايت: دقيقةٌ من فيديو الجوال بجودة ٧٢٠p تقارب الثلاثين،
--    وبجودة ١٠٨٠p تتجاوز المئة — فمن صوّر بأعلى جودةٍ يُردّ برسالةٍ من
--    التخزين نفسه، ويُقال له في التطبيق ما يفعل. والحدُّ هنا هو الحارس
--    الحقيقي على الدقيقة، لأن المدّة رقمٌ يرسله العميل والحجم لا.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'service-media', 'service-media', true, 52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp',
    'video/mp4', 'video/quicktime', 'video/3gpp',
    'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/x-m4a'
  ]
)
on conflict (id) do update set
  public             = true,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- المسار `<provider_id>/<service_id>/<ملف>`، وأوّل جزءٍ منه هو المفتاح: من
-- كتب مساراً بمعرّف مزوّدٍ غيره رُدّ رفعُه.
drop policy if exists "service media is public" on storage.objects;
create policy "service media is public" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'service-media');

drop policy if exists "provider uploads own media" on storage.objects;
create policy "provider uploads own media" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'service-media'
    and (storage.foldername(name))[1] = public.current_provider()::text
  );

drop policy if exists "provider replaces own media" on storage.objects;
create policy "provider replaces own media" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'service-media'
    and (storage.foldername(name))[1] = public.current_provider()::text
  );

-- الحذف للمزوّد ولمن يملك الكتابة في الإدارة: وسائطُ مسيئةٌ تُرفع اليوم
-- وتبقى إلى أن يُزيلها أحد، ولو لم يملك المسؤول إلّا الطلب من صاحبها لبقيت.
drop policy if exists "provider or admin deletes media" on storage.objects;
create policy "provider or admin deletes media" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'service-media'
    and (
      (storage.foldername(name))[1] = public.current_provider()::text
      or public.can_write()
    )
  );

-- ----------------------------------------------------------------------------
-- ٥. الغلاف في قائمة الخدمات
--
--    بطاقةُ خدمةٍ بلا صورةٍ في الاستكشاف تُلغي نصف الفائدة: الصور تُرفع ثم لا
--    تُرى إلّا لمن فتح التفاصيل — أي لمن اقتنع أصلاً. فالغلاف يُضاف إلى
--    `v_services` نفسها، فتأتي مع الصفّ في نداءٍ واحد لا في نداءٍ لكل بطاقة.
--
--    والأعمدة تُلحق في الآخر: `create or replace view` يقبل الزيادة ويرفض
--    الحذف أو تغيير الترتيب.
-- ----------------------------------------------------------------------------
create or replace view public.v_services
with (security_invoker = true) as
select
  s.id,
  s.title,
  s.description,
  s.price,
  s.price_to,
  s.unit,
  s.deposit_percent,
  s.duration_minutes,
  s.attributes,
  s.images,
  s.category_id,
  c.name  as category_name,
  c.slug  as category_slug,
  s.provider_id,
  p.business_name as provider_name,
  p.governorate   as provider_governorate,
  p.rating        as provider_rating,
  p.reviews_count as provider_reviews_count,
  p.is_featured   as provider_is_featured,
  pol.name  as cancellation_policy_name,
  pol.rules as cancellation_rules,
  (select m.path
     from public.service_media m
    where m.service_id = s.id and m.kind = 'image'
    order by m.sort_order, m.created_at
    limit 1)                                        as cover_path,
  (select count(*) from public.service_media m where m.service_id = s.id and m.kind = 'image')
                                                    as images_count,
  exists (select 1 from public.service_media m where m.service_id = s.id and m.kind = 'video')
                                                    as has_video,
  exists (select 1 from public.service_media m where m.service_id = s.id and m.kind = 'audio')
                                                    as has_audio
from public.provider_services s
join public.service_providers p on p.id = s.provider_id
join public.service_categories c on c.id = s.category_id
left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id;

-- ----------------------------------------------------------------------------
-- ٦. التحقّق
-- ----------------------------------------------------------------------------
select 'جدول الوسائط' as البند,
       (select count(*)::text from information_schema.tables
         where table_schema = 'public' and table_name = 'service_media') as النتيجة
union all
select 'سلّة service-media', count(*)::text from storage.buckets where id = 'service-media'
union all
select 'سياسات الصفّ', count(*)::text from pg_policies
  where schemaname = 'public' and tablename = 'service_media'
union all
select 'سياسات السلّة', count(*)::text from pg_policies
  where schemaname = 'storage' and tablename = 'objects' and policyname like '%media%'
union all
select 'الغلاف في v_services', count(*)::text from information_schema.columns
  where table_schema = 'public' and table_name = 'v_services' and column_name = 'cover_path';
