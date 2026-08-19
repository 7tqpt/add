-- ============================================================================
--  استعادة أقسام الخدمات
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run.
--
--  رفيقُ `clear_categories.sql`. أُفرِد في ملفٍّ قائمٍ بذاته لسببٍ عمليّ:
--  لوحةُ التحكم تُفعّل القسم وتُعطّله ولا تُنشئه — فمن أفرغ الجدول لا يجد
--  في الواجهة طريقاً لإعادته. فهذا هو الطريق.
--
--  هذه الأقسام الاثنا عشر هي نفسها التي في `seed.sql`، ومعها «الحقول
--  الخاصة بالقسم» في `custom_fields` — السعة، عدد الأشخاص، عدد أفراد
--  الفرقة… وهي التي تُبنى منها استمارةُ مقدّم الخدمة في التطبيق.
--
--  ولتغييرها: عدّل الاسم أو الوصف أو الحقول هنا قبل التشغيل. و`slug`
--  معرّفٌ برمجيّ لا يُترجم ولا يُغيَّر بعد أن تُبنى عليه بيانات.
--
--  وتشغيلُه مرّتين لا يضرّ: `on conflict (slug) do nothing` يتخطّى
--  الموجود بدل أن يُخطئ أو يُكرّر.
-- ============================================================================

insert into public.service_categories (name, slug, description, sort_order, custom_fields) values
  ('القاعات والخيام', 'halls',
   'صالات، خيام، استراحات، السعة، الموقع، الصور، الأسعار والمواعيد المتاحة.', 1,
   '[{"key":"capacity","label":"السعة","type":"number","required":true},
     {"key":"has_parking","label":"يوجد موقف سيارات","type":"boolean","required":false},
     {"key":"indoor","label":"مغلقة","type":"boolean","required":false}]'::jsonb),

  ('الطبخ والضيافة', 'catering',
   'طباخين، مطابخ مناسبات، بوفيهات، ذبائح، مندي وحنيذ، قهوة وشاي، وطاقم تقديم.', 2,
   '[{"key":"guests_capacity","label":"عدد الأشخاص","type":"number","required":true},
     {"key":"menu_style","label":"نمط الوجبة","type":"text","required":false},
     {"key":"includes_service","label":"يشمل طاقم التقديم","type":"boolean","required":false}]'::jsonb),

  ('الفنانين والفرق', 'artists',
   'فنانين، فرق فنية، منشدين، دي جي، زفة، وفنانين مع معداتهم.', 3,
   '[{"key":"members","label":"عدد أفراد الفرقة","type":"number","required":false},
     {"key":"genre","label":"النوع","type":"text","required":false}]'::jsonb),

  ('الصوت والمعدات', 'sound',
   'سماعات، مكبرات، ميكروفونات، أجهزة دي جي، معدات صوت وحفلات وتأجير المعدات.', 4,
   '[{"key":"coverage_area","label":"مساحة التغطية","type":"text","required":false}]'::jsonb),

  ('التصوير والإضاءة', 'photography',
   'مصورين، فرق تصوير، تصوير فيديو وفوتوغرافي، كاميرات، درون، وإضاءة الحفلات والمسرح.', 5,
   '[{"key":"has_drone","label":"تصوير بالدرون","type":"boolean","required":false},
     {"key":"team_size","label":"عدد المصورين","type":"number","required":false}]'::jsonb),

  ('الموية والطليع والخدمات المساندة', 'support',
   'موية، قريح، طليع وأي خدمات مساندة يعتمدها النظام حسب المدينة.', 6,
   '[{"key":"quantity_unit","label":"وحدة القياس","type":"text","required":false}]'::jsonb),

  ('السيارات', 'cars',
   'سيارات للعريس، الزفة، الضيوف، سيارات فخمة، باصات وخدمات نقل.', 7,
   '[{"key":"car_model","label":"الطراز","type":"text","required":false},
     {"key":"seats","label":"عدد الركاب","type":"number","required":false}]'::jsonb),

  ('الملبوسات', 'attire',
   'ملابس العريس والعروس والضيوف والأطفال، شراء، إيجار، تفصيل وإكسسوارات.', 8,
   '[{"key":"mode","label":"نوع التعامل","type":"text","required":false}]'::jsonb),

  ('متعهدين الحفلات', 'planners',
   'تنظيم وتجهيز شامل، باقات، تنسيق الخدمات، الديكور، الصوت، التصوير والزفة.', 9,
   '[{"key":"package_scope","label":"نطاق الباقة","type":"text","required":false}]'::jsonb),

  ('التجميل والكوافير', 'beauty',
   'مكياج، تسريحات، كوافير، تجهيز العروس وخدمات التجميل.', 10,
   '[{"key":"home_service","label":"خدمة منزلية","type":"boolean","required":false}]'::jsonb),

  ('الديكور والكوشة والورد', 'decor',
   'كوش، ورد، ديكور، خلفيات، طاولات، كراسي وتجهيزات المكان.', 11,
   '[{"key":"style","label":"الطراز","type":"text","required":false}]'::jsonb),

  ('الطباعة', 'printing',
   'بطاقات الدعوة، اللوحات، الاستيكرات، التوزيعات، أرقام الطاولات، بطاقات الشكر والبنرات.', 12,
   '[{"key":"min_quantity","label":"أقل كمية","type":"number","required":false}]'::jsonb)
on conflict (slug) do nothing;

select 'بعد الاستعادة' as المرحلة,
       (select count(*) from public.service_categories) as الأقسام;
