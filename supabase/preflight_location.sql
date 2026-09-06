-- ============================================================================
--  قبل تشغيل location.sql و nearby.sql و share_link.sql
-- ============================================================================
--
--  **قراءةٌ محضة — لا يغيّر شيئاً.** الصقه في محرّر SQL واضغط Run.
--
--  ولماذا يُسأل قبل التشغيل: `location.sql` **يُعيد كتابة
--  `api_create_booking`** — وهي الدالّةُ التي يمرّ بها كلُّ حجزٍ في المنصّة.
--  وهي في نسختها هناك تقرأ الكوبونات وعنوانَ المستخدم، فإن لم يكن
--  `coupons.sql` و`profile_extras.sql` قد شُغِّلا لَسقط الحجزُ كلُّه بعد
--  التشغيل — لا الخريطةُ وحدَها.
--
--  والعمودُ الأخير يقول ما تفعل، فلا تحتاج أن تقارن بنفسك.
-- ============================================================================

with checks as (

  -- ── الشروط السابقة ────────────────────────────────────────────────────
  select 1 as ord,
         'شرطٌ سابق' as النوع,
         'profile_extras.sql — دفترُ العناوين' as الملف,
         exists (select 1 from information_schema.tables
                  where table_schema = 'public' and table_name = 'user_addresses') as مُشغَّل

  union all
  select 2, 'شرطٌ سابق', 'coupons.sql — الكوبونات',
         exists (select 1 from information_schema.tables
                  where table_schema = 'public' and table_name = 'coupons')

  union all
  select 3, 'شرطٌ سابق', 'service_media.sql — معرضُ الخدمة',
         exists (select 1 from information_schema.tables
                  where table_schema = 'public' and table_name = 'service_media')

  -- ── الثلاثة المطلوبة ──────────────────────────────────────────────────
  union all
  select 4, '١ — يُشغَّل أوّلاً', 'location.sql — النقطةُ على الخريطة',
         exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'user_addresses'
                    and column_name = 'latitude')

  union all
  select 5, '٢ — بعد الأوّل', 'nearby.sql — الترتيبُ بالمسافة',
         exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'api_providers_nearby')

  union all
  select 6, '٣ — مستقلٌّ عنهما', 'share_link.sql — رابطُ الدعوة',
         exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'app_settings'
                    and column_name = 'share_url')
)

select النوع,
       الملف,
       case when مُشغَّل then 'نعم' else 'لا' end as مُشغَّل,
       case
         when مُشغَّل and النوع = 'شرطٌ سابق' then '—'
         when مُشغَّل then 'تمّ، ولا ضررَ في إعادته'
         when النوع = 'شرطٌ سابق' then '⚠ شغّله قبل الثلاثة'
         else 'شغّله'
       end as ماذا_تفعل
  from checks
 order by ord;

-- ----------------------------------------------------------------------------
--  وبعد `share_link.sql` يبقى سطرٌ واحدٌ يُكتب بيدك — الرابطُ نفسُه:
--
--    update public.app_settings
--       set share_url = 'https://github.com/7tqpt/add/releases/latest'
--     where id = 1;
--
--  ولا يُملأ بقيمةٍ من عندنا: ما يُرسَل إلى الناس يكون باسمك أنت.
-- ----------------------------------------------------------------------------
