-- ============================================================================
--  أهي الدالّةُ التي في المستودع؟ — بصمةُ النصّ، لا وجودُ سطرٍ فيه
--
--  يقرأ ولا يغيّر شيئاً. وجملةٌ واحدةٌ: المحرّرُ يعرض آخرَ جملةٍ وحدَها.
-- ============================================================================
--
--  ثبت بالقياس أنّ ثلاثةَ مستخدمين كانوا موجودين — ولهم أجهزة — وقتَ كلّ
--  حملةٍ من الأربع، وأنّ `broadcast_audience('all')` تُخرج ثلاثةً، وأنّ
--  الحملاتِ كلَّها سجّلت صفراً.
--
--  **فالدالّةُ التي تعمل ليست التي أقرؤها.** وفحصي السابق سألها سؤالاً
--  ضعيفاً — «أفيها `insert into public.notifications`؟» — فأجاب «نعم» وهو
--  لا ينفي أن يكون ما بعد `from` غيرَ ما ينبغي. **وسؤالٌ عن وجود سطرٍ في
--  نصٍّ لا يُثبت أنّ النصَّ هو هو.**
--
--  فتُقابَل البصمةُ كلُّها: `md5(prosrc)` لكلّ دالّة، بما وُلد من
--  `broadcast.sql` في المستودع. واختلافُ حرفٍ واحدٍ يُظهره.
--
--  ⚠️ وإن خرج «تخالف» فالعلاجُ سطرٌ: الصق `supabase/broadcast.sql` كاملاً
--     في المحرّر وشغّله. وهو آمنٌ عند التكرار.
-- ============================================================================

with expected(name, h) as (
  values ('api_admin_broadcast', 'cc2c139e3d4e81e9e634469b47bfd0c1'),
         ('broadcast_audience',  'b48e337497426096089063cc32920fda'),
         ('send_due_broadcasts', 'be97965fac4dd0772beed8f82396d2f7')
), live as (
  select p.proname as name, md5(p.prosrc) as h, length(p.prosrc) as len
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('api_admin_broadcast', 'broadcast_audience', 'send_due_broadcasts')
)
select 1 as ت,
       e.name as الدالّة,
       case when l.name is null then '❌ لا وجودَ لها في قاعدتك'
            when l.h = e.h     then '✅ هي هي — نصّاً بنصّ'
            else '❌ **تخالف المستودع** — طولُها ' || l.len
                 || ' حرفاً، وبصمتُها ' || left(l.h, 8)
                 || ' والمنتظَر ' || left(e.h, 8)
       end as الحكم
  from expected e left join live l on l.name = e.name

union all
select 2, '— ماذا تفعل إن خالفت —',
       'الصق supabase/broadcast.sql كاملاً في تبويبٍ جديدٍ وشغّله. آمنٌ عند التكرار.'
order by ت, الدالّة;
