-- ============================================================================
--  صورةُ القسم: القاعاتُ تُعرض بقاعة، لا بأيقونةٍ رماديّة
--
--  شغّله بعد `install.sql` و`roles.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** الشاشةُ الأولى في التطبيق اثنتا عشرة بطاقةَ قسم، وكلُّها
--  أيقونةٌ خطّيّةٌ على لون. وهي تقول «قاعات» ولا تُري قاعة. ومن يفتح تطبيقَ
--  أعراسٍ أوّلَ مرّة يحكم عليه في ثانيتين بما رآه، لا بما قرأ.
--
--  ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
--
--  **١) والصورةُ لا تُلغي الأيقونة بل تعلوها.** العمودُ يقبل الفراغ، والبطاقةُ
--  تعود إلى أيقونتها إن لم تكن ثمّ صورة. فمن شغّل هذا الملفّ ولم يرفع صورةً
--  بعدُ لا تنكسر شاشتُه ولا تصير بيضاء — وهذا هو الحالُ يومَ التشغيل نفسه.
--
--  **٢) ولا يرفعها إلّا من يملك «الكتالوج».** الأقسامُ ملكُ المنصّة لا ملكُ
--  مزوّد: من ملك رفعَ صورةٍ لقسم «القاعات» ملك واجهةَ التطبيق كلِّها. فالسياسةُ
--  هي `can_write_area('catalog')` نفسُها التي تحرس الجدول — لا سياسةٌ ثانيةٌ
--  تُكتب بيدٍ فتفترق عنها.
--
--  **٣) والسلّةُ عامّةُ القراءة.** الصورةُ تُعرض قبل تسجيل الدخول — الشاشةُ
--  الأولى تُرى بلا حساب — فرابطٌ موقَّعٌ بساعةٍ لا يصلح هنا، ولا سرَّ في صورة
--  قاعةٍ يعرضها صاحبُها.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- العمود
--
-- **مسارٌ لا رابط.** الرابطُ الكامل يحمل في جوفه اسمَ مشروع Supabase، فلو
-- نُقلت القاعدةُ يوماً لَبطلت كلُّ الصور. والمسارُ يبقى، ويُشتقّ منه الرابط
-- عند العرض — وهو العرفُ نفسه في `logo_path` و`cover_path` هنا.
-- ----------------------------------------------------------------------------
alter table public.service_categories
  add column if not exists image_path text not null default '';

-- ----------------------------------------------------------------------------
-- السلّة
--
-- ونصفُ ميجابايت حدٌّ كافٍ: صورةُ بطاقةٍ تُعرض بعرض ١٦٠ بكسلاً على الشاشة،
-- ومن رفع فيها صورةً بثمانية ميجابايت يدفع ثمنَها كلُّ من فتح التطبيق على
-- شبكة جوالٍ يمنيّة. والحدُّ يُردّ من التخزين نفسه لا من نيّة الرافع.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('category-images', 'category-images', true, 524288,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "category images are public" on storage.objects;
create policy "category images are public" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'category-images');

-- **والكتابةُ لأصحاب «الكتالوج» وحدهم** — لا لكلّ مسجَّلٍ في التطبيق. ولولا
-- هذا لَاستطاع أيُّ عميلٍ أن يبدّل صورةَ قسمٍ في الشاشة الأولى.
drop policy if exists "catalog writers upload category images" on storage.objects;
create policy "catalog writers upload category images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'category-images' and public.can_write_area('catalog'));

drop policy if exists "catalog writers replace category images" on storage.objects;
create policy "catalog writers replace category images" on storage.objects
  for update to authenticated
  using (bucket_id = 'category-images' and public.can_write_area('catalog'))
  with check (
    bucket_id = 'category-images' and public.can_write_area('catalog'));

drop policy if exists "catalog writers delete category images" on storage.objects;
create policy "catalog writers delete category images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'category-images' and public.can_write_area('catalog'));

commit;
