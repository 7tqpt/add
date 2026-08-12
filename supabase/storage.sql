-- ============================================================================
--  تخزين مستندات التوثيق
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run. آمن للتكرار.
--
--  ما الذي يحلّه:
--    شاشة مقدّم الخدمة تطلب من المسؤول قبول «الهوية الوطنية» أو رفضها، ولا
--    تعطيه وسيلة لفتحها. الجدول فيه عمود file_url منذ البداية لكنه فارغ، لأن
--    المستندات لم يكن لها مكان تُرفع إليه أصلاً. هذا الملف يصنع المكان.
--
--  ⚠️  الحاوية خاصة (private) لا عامة، وهذا ليس تفصيلاً.
--
--      الحاوية العامة تعني أن رابط صورة البطاقة الشخصية يفتح لأي شخص في
--      العالم يعرفه — بلا تسجيل دخول، وبلا أن تعلم أنت. صور الهويات والسجلات
--      التجارية لمئات المقدّمين تصير مكشوفة برابط واحد يُسرَّب. الحاوية الخاصة
--      تجعل كل فتحة تمرّ على سياسة، والرابط الذي تُصدره اللوحة موقَّت بدقائق.
--
--  اصطلاح المسار:  <provider_id>/<document_id>.<ext>
--    الجزء الأول من المسار هو معرّف مقدّم الخدمة، وعليه تُبنى كل السياسات
--    أدناه: يرفع في مجلّده هو ويقرأ منه هو، لا غير.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- الحاوية
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'provider-docs',
  'provider-docs',
  false,                                   -- خاصة. لا تحوّلها لعامة.
  10485760,                                -- ١٠ ميجابايت للملف
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public             = false,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ----------------------------------------------------------------------------
-- السياسات
--
--  storage.objects جدول عادي عليه RLS، فسياساته تُكتب كأي سياسة أخرى.
--  `(storage.foldername(name))[1]` يعطي الجزء الأول من المسار — مجلّد المالك.
-- ----------------------------------------------------------------------------

drop policy if exists "provider uploads own documents" on storage.objects;
create policy "provider uploads own documents"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'provider-docs'
  and (storage.foldername(name))[1] = public.current_provider()::text
);

drop policy if exists "provider reads own documents" on storage.objects;
create policy "provider reads own documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'provider-docs'
  and (storage.foldername(name))[1] = public.current_provider()::text
);

-- الاستبدال قبل المراجعة مسموح — مستند مرفوض يُعاد رفعه بملف صحيح.
drop policy if exists "provider replaces own documents" on storage.objects;
create policy "provider replaces own documents"
on storage.objects for update to authenticated
using (
  bucket_id = 'provider-docs'
  and (storage.foldername(name))[1] = public.current_provider()::text
);

-- المسؤول يقرأ كل شيء — وهذا كامل صلاحيته هنا. لا يرفع ولا يحذف مستندَ أحد:
-- المراجعة حكمٌ على ملف، لا تعديل له.
drop policy if exists "admin reads all documents" on storage.objects;
create policy "admin reads all documents"
on storage.objects for select to authenticated
using (bucket_id = 'provider-docs' and public.is_admin());

-- ============================================================================
--  التحقق — المتوقّع: الحاوية موجودة وقيمة public = false، و ٤ سياسات
-- ============================================================================
select 'الحاوية' as البند,
       coalesce((select case when public then 'عامة ⚠️' else 'خاصة ✅' end
                   from storage.buckets where id = 'provider-docs'), 'غير موجودة') as القيمة
union all
select 'السياسات', count(*)::text
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and policyname like '%documents%';
