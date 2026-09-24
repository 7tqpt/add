-- ============================================================================
--  كم كان الجمهورُ **لحظةَ** كلّ إرسال — لا اليومَ
--
--  يقرأ ولا يغيّر شيئاً. وجملةٌ واحدةٌ: المحرّرُ يعرض آخرَ جملةٍ وحدَها.
-- ============================================================================
--
--  أُغلق كلُّ ما سواه: الدالّةُ تُخرج ٣ بالقيمة المخزَّنة، ولا
--  `force row level security` على `app_users`، ونسخةٌ واحدةٌ من كلّ دالّة،
--  وفرعُ `all` في موضعه.
--
--  فبقي الفرقُ بين **الآن** و**حينئذٍ**: `broadcast_audience` تُخرج ثلاثةً
--  اليوم، وقد تكون أخرجت صفراً وقتَ الضغط لأنّ أصحابَها لم يكونوا قد
--  سجّلوا بعد. ولا يُرى ذلك في عددٍ يُقرأ اليوم — يُرى بمقابلة
--  `app_users.created_at` بـ`push_notifications.sent_at` صفّاً بصفّ.
--
--  فإن خرج «من كان موجوداً وقتَها = 0» في الحملات كلِّها، فلا عطبَ في شيء:
--  الحملاتُ خرجت إلى فراغ، ويكفي أن تُرسل واحدةً الآن.
-- ============================================================================

select 1 as ت,
       'حملة ' || to_char(p.created_at, 'HH24:MI') || ' — [' || p.audience || ']' as البند,
       'سجّلت ' || p.recipients || ' · وكان موجوداً وقتَها: '
         || (select count(*) from public.app_users u
              where u.status <> 'suspended'
                and u.created_at <= coalesce(p.sent_at, p.created_at))
         || ' · ومنهم بجهازٍ: '
         || (select count(distinct u.id) from public.app_users u
              join public.user_devices d on d.user_id = u.id
             where u.status <> 'suspended'
               and u.created_at <= coalesce(p.sent_at, p.created_at)
               and d.push_token is not null and d.push_enabled) as القيمة
  from public.push_notifications p

union all
select 2,
       'مستخدم: ' || u.full_name || ' (' || u.status || ')',
       'سُجّل ' || to_char(u.created_at, 'MM-DD HH24:MI')
         || ' · أجهزته: '
         || (select count(*) from public.user_devices d
              where d.user_id = u.id and d.push_token is not null and d.push_enabled)
  from public.app_users u

union all
select 3, '— الحكم —',
       case when (select count(*) from public.push_notifications p
                   where exists (select 1 from public.app_users u
                                  where u.status <> 'suspended'
                                    and u.created_at <= coalesce(p.sent_at, p.created_at))) = 0
            then '✅ لا عطبَ في شيء: كلُّ حملةٍ خرجت قبل أن يوجد مستخدمٌ واحد. أرسل واحدةً الآن.'
            else '❌ كانت ثَمَّ مستخدمون وقتَ إرسالِ حملةٍ على الأقلّ، ومع ذلك سجّلت صفراً — فالعلّةُ في الدالّة.'
       end
order by ت, البند;
