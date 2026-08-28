-- ============================================================================
--  فحص الكوبونات: هل وصل `coupons.sql` كاملاً؟
--
--  شغّله كاملاً في محرّر SQL. لا يغيّر شيئاً — يقرأ ويحكم.
-- ============================================================================
--
--  **ولماذا لا يكفي أن يقول المحرّر «Success»:** الملفُّ يمرّ بنجاحٍ وهو ناقص
--  في حالتين وقعتا في هذا المشروع قبل اليوم:
--
--    ١. أن يُلصق نصفُه — نسخةٌ قديمةٌ محفوظة، أو تحديدٌ لم يبلغ آخر الملفّ.
--       والنصفُ الأوّل يُنشئ الجداول فيبدو كلُّ شيء تماماً، والنصفُ الثاني
--       فيه الدوالُّ والمُشغِّل.
--    ٢. أن يُشغَّل على قاعدةٍ لم يُشغَّل عليها `api.sql` بعدُ، فيسقط عند أوّل
--       مرجعٍ لجدولٍ غير موجود، ويبقى ما قبل السقوط.
--
--  وأخطرُ ما يمرّ صامتاً هو **البند ٦**: لو بقيت `api_create_booking` بتوقيعها
--  القديم لَما وصل الكودُ إلى الخادم أصلاً — يكتبه العميل، ويقول له التطبيق
--  «خُصم كذا»، ثمّ يُنشأ الحجزُ بلا خصمٍ ولا كود. ولا خطأَ في أيّ شاشة.
-- ============================================================================

with checks as (

  select 1 as ترتيب, 'جدول الأكواد' as البند,
         (select count(*) > 0 from information_schema.tables
           where table_schema = 'public' and table_name = 'coupons') as حسن,
         'شغّل coupons.sql كاملاً' as الخطوة

  union all
  select 2, 'جدول الاستعمالات',
         (select count(*) > 0 from information_schema.tables
           where table_schema = 'public' and table_name = 'coupon_redemptions'),
         'شغّل coupons.sql كاملاً'

  union all
  select 3, 'عمودا الحجز (الكود والخصم)',
         (select count(*) = 2 from information_schema.columns
           where table_schema = 'public' and table_name = 'bookings'
             and column_name in ('coupon_code', 'discount_amount')),
         'شغّل coupons.sql — والحجزُ بلا العمودين لا يحفظ خصماً'

  union all
  select 4, 'عمود الخصم في الفاتورة',
         (select count(*) > 0 from information_schema.columns
           where table_schema = 'public' and table_name = 'invoices'
             and column_name = 'discount'),
         'شغّل coupons.sql — وفاتورةٌ بلا هذا العمود لا تقول للعميل ما خُصم'

  union all
  select 5, 'دالّة التحقّق من الكود',
         (select count(*) > 0 from pg_proc
           where proname = 'api_check_coupon' and pronamespace = 'public'::regnamespace),
         'شغّل النصف الثاني من coupons.sql'

  union all
  -- **البند الحاسم.** توقيعٌ واحدٌ يذكر `p_coupon_code`: وجودُ توقيعين معاً
  -- يجعل النداء ملتبساً، ووجودُ القديم وحده يبتلع الكود صامتاً.
  --
  -- **ويُسأل عن اسم المعامل لا عن عددها.** كان يعدّ «تسعة» فكسره `location.sql`
  -- بعد أيّامٍ حين أضاف معاملَي الموقع — فقال «❌ شغّل coupons.sql» لقاعدةٍ
  -- شُغِّل عليها الملفُّ وزيادة. وفحصٌ يُكذّب الصوابَ يُهمَل بعد مرّتين.
  select 6, 'دالّة الحجز تقبل كوداً',
         (select count(*) = 1 from pg_proc
           where proname = 'api_create_booking'
             and pronamespace = 'public'::regnamespace
             and pg_get_function_arguments(oid) like '%p_coupon_code%'),
         'شغّل coupons.sql كاملاً — فيه `drop` للتوقيع القديم ثمّ الجديد'

  union all
  select 7, 'العمولةُ عند القبول تعرف الخصم',
         (select count(*) > 0 from pg_proc
           where proname = 'api_respond_to_booking'
             and pronamespace = 'public'::regnamespace
             and pg_get_functiondef(oid) like '%discount_amount%'),
         'شغّل coupons.sql — وبدونه يخرج الخصمُ من جيب مقدّم الخدمة يوم التسوية'

  union all
  select 8, 'مُشغِّل ردّ الكود عند الإلغاء',
         (select count(*) > 0 from pg_trigger
           where tgname = 'bookings_release_coupon' and not tgisinternal),
         'شغّل coupons.sql — وبدونه يحترق كودُ العميل في حجزٍ اعتذر عنه المزوّد'

  union all
  select 9, 'طريقة العرض للوحة',
         (select count(*) > 0 from information_schema.views
           where table_schema = 'public' and table_name = 'v_coupons'),
         'شغّل آخر coupons.sql — وبدونها تبقى صفحة «أكواد الخصم» فارغة'

  union all
  -- **ولا سياسةَ قراءةٍ لغير الإدارة.** لو فُتحت لَجمع أوّلُ فضوليٍّ كلَّ كودٍ
  -- في المنصّة من التطبيق نفسه.
  select 10, 'الأكواد محجوبةٌ عن العملاء',
         (select count(*) = 1 from pg_policies
           where schemaname = 'public' and tablename = 'coupons' and cmd = 'SELECT'),
         'شغّل coupons.sql — أو احذف أيّ سياسة قراءةٍ أضفتها بيدك'
)

select
  case when حسن then '✅' else '❌' end as الحكم,
  البند,
  case when حسن then '—' else الخطوة end as "ما تفعله"
from checks
order by ترتيب;

-- ----------------------------------------------------------------------------
-- ملحق: أكوادُك وحصادُها
--
-- جدولٌ فارغٌ هنا **ليس عطباً** — يعني أنّك لم تُنشئ كوداً بعد. أنشئه من
-- اللوحة: «المالية ← أكواد الخصم ← كود جديد».
-- ----------------------------------------------------------------------------
select
  c.code as الكود,
  case c.kind when 'percent' then c.value || '٪' else to_char(c.value, 'FM999,999,999') end
    as الخصم,
  case when c.is_live then 'سارٍ' else 'موقوف/منتهٍ' end as الحال,
  c.redemptions as "مرّات الاستعمال",
  to_char(c.total_discount, 'FM999,999,999') as "ما كلّف",
  c.ends_at as "ينتهي"
from public.v_coupons c
order by c.created_at desc
limit 20;
