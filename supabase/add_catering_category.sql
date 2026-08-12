-- ============================================================================
--  إضافة قسم «الطبخ والضيافة»
--
--  الطعام من أكبر بنود العرس اليمني، وكان ساقطاً من قائمة الأقسام. هذا الملف
--  يضيفه وحده دون إعادة تشغيل seed.sql، فلا يمسّ بياناتك القائمة.
--
--  التشغيل مرة ثانية آمن: on conflict على slug يحدّث ولا يكرّر.
-- ============================================================================

insert into public.service_categories (name, slug, description, sort_order, custom_fields)
values (
  'الطبخ والضيافة',
  'catering',
  'طباخين، مطابخ مناسبات، بوفيهات، ذبائح، مندي وحنيذ، قهوة وشاي، وطاقم تقديم.',
  2,
  '[{"key":"guests_capacity","label":"عدد الأشخاص","type":"number","required":true},
    {"key":"menu_style","label":"نمط الوجبة","type":"text","required":false},
    {"key":"includes_service","label":"يشمل طاقم التقديم","type":"boolean","required":false}]'::jsonb
)
on conflict (slug) do update set
  name          = excluded.name,
  description   = excluded.description,
  sort_order    = excluded.sort_order,
  custom_fields = excluded.custom_fields;

-- الترتيب يُثبَّت بقيم صريحة لا بزيادة مقدار.
--
-- `sort_order = sort_order + 1` تبدو أبسط، لكنها تزيد مرة أخرى في كل تشغيل
-- فتترك فجوات (1,2,5,6,…) — وقد كشف ذلك اختبارٌ يشغّل الملف مرتين. القيمة
-- الصريحة تُنتج الترتيب نفسه مهما تكرّر التنفيذ.
update public.service_categories c
   set sort_order = v.rank
  from (values
    ('halls', 1), ('catering', 2), ('artists', 3), ('sound', 4),
    ('photography', 5), ('support', 6), ('cars', 7), ('attire', 8),
    ('planners', 9), ('beauty', 10), ('decor', 11), ('printing', 12)
  ) as v(slug, rank)
 where c.slug = v.slug and c.sort_order is distinct from v.rank;

-- للتحقق:
select sort_order, name, slug from public.service_categories order by sort_order;
