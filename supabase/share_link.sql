-- رابطُ الدعوة الذي يُرسَل مع كلّ مشاركة.
--
-- **ولمَ في القاعدة لا في التطبيق:** اليوم هو صفحةُ الإصدار على GitHub،
-- وغداً متجرُ Play، وبعدَه صفحةٌ على الوِب. ولو كُتب في شيفرة التطبيق
-- لَاحتاج كلُّ تبديلٍ نسخةً جديدةً تُنشَر ثمّ ينتظر الناسُ حتى يحدّثوا —
-- **والذين لا يحدّثون يرسلون رابطاً ميّتاً إلى أهلهم شهوراً**، وكلُّ رسالةٍ
-- منها دعوةٌ ضائعة.
--
-- ويُقرأ من `app_settings` وهي مقروءةٌ للعامّة أصلاً (سياسة
-- `settings_public_read`)، فلا سياسةَ جديدةً تُكتب.

alter table public.app_settings
  add column if not exists share_url text not null default '';

comment on column public.app_settings.share_url is
  'رابطُ تنزيل التطبيق كما يخرج في رسائل المشاركة. فارغٌ يعني: شارِك بلا '
  'سطر دعوة. ولا يُقبل إلّا https:// — ورابطٌ يُنذر في المتصفّح يُقرأ احتيالاً '
  'في رسالةِ دعوة.';

-- القاعدةُ نفسُها المكتوبة على `app_versions.download_url`، وهي مقيسةٌ في
-- `supabase/tests/` بأنّ التطبيق واللوحة والقاعدة يقولون قولاً واحداً.
alter table public.app_settings
  drop constraint if exists app_settings_share_url_https;

alter table public.app_settings
  add constraint app_settings_share_url_https
  check (share_url = '' or share_url ~ '^https://');

-- ولا يُملأ بقيمةٍ من عندنا: صاحبُ المنصّة يضعه من اللوحة أو من هنا، فيكون
-- ما يُرسَل إلى الناس باسمه هو لا بافتراضٍ كتبناه نحن.
--
-- ولملئه الآن:
--
--   update public.app_settings
--      set share_url = 'https://github.com/…/releases/latest'
--    where id = 1;
