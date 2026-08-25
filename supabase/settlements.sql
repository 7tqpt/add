-- ============================================================================
--  التسويات: ما تدين به المنصّة لمقدّمي الخدمة، محسوباً لا مقدَّراً
--
--  شغّله بعد `roles.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** الجداول كاملة، وصفحةُ «مستحقّات الشركاء» في اللوحة
--  تعرضها وتغيّر حالاتها — **ولا أحد يُنشئها**. فالمنصّة تقبض من العملاء
--  وتحتفظ بحصّتها، والباقي دَينٌ لا سجلّ له إلّا في أوراق صاحبها. وأوّلُ خلافٍ
--  على مبلغٍ يُنهي شراكة.
--
--  **وما يُحتسب هو المقبوض لا المستحقّ:** `paid_amount` لا `total_price`.
--  المنصّة لا تستطيع أن تسلّم ما لم تقبضه، وتسويةٌ مبنيّةٌ على السعر الكامل
--  تجعلها مدينةً بمالٍ في جيب العميل بعدُ.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- احتساب فترة
--
--  **وحجزٌ واحدٌ لا يدخل تسويتين:** الفهرس `settlement_items_booking_once_idx`
--  يمنع ذلك في القاعدة، وهذه الدالّة تستثني المحتسَب سلفاً — فإعادةُ التشغيل
--  على الفترة نفسها لا تُنتج شيئاً، ولا تسقط.
-- ----------------------------------------------------------------------------
create or replace function public.api_admin_build_settlements(
  p_from date, p_to date)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  made integer := 0;
  row record;
  sid uuid;
begin
  if not public.can_write_area('finance') then
    raise exception 'احتساب التسويات لمن يملك الكتابة في المال';
  end if;
  if p_to < p_from then
    raise exception 'نهاية الفترة قبل بدايتها';
  end if;

  for row in
    select b.provider_id,
           max(b.provider_name)                             as provider_name,
           -- المقبوض لا المستحقّ.
           sum(b.paid_amount - b.refunded_amount)           as gross,
           sum(b.commission_amount)                         as commission,
           array_agg(b.id)                                  as bookings
      from public.bookings b
     where b.status = 'completed'
       and b.provider_id is not null
       and b.event_date between p_from and p_to
       and b.paid_amount > b.refunded_amount
       and not exists (select 1 from public.settlement_items i where i.booking_id = b.id)
     group by b.provider_id
  loop
    -- القيود تمنع سالباً وتمنع أن يتجاوز المجموعُ الإجمالي: عمولةٌ تفوق
    -- المقبوض تقع حين يُلغى حجزٌ جزئياً، فتُقصر على المقبوض ويصير الصافي صفراً.
    -- والاحتساب يجب أن يقف عند الصفر لا أن يسقط بقيد.
    declare
      gross numeric(14, 2) := greatest(row.gross, 0);
      comm  numeric(14, 2) := least(greatest(row.commission, 0), greatest(row.gross, 0));
    begin
      insert into public.settlements
             (reference, provider_id, provider_name, period_start, period_end,
              gross_amount, commission_amount, net_amount, status)
      values ('STL-' || to_char(p_to, 'YYYYMM') || '-' ||
                upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
              row.provider_id, row.provider_name, p_from, p_to,
              gross, comm, gross - comm, 'pending')
      returning id into sid;

      insert into public.settlement_items
             (settlement_id, booking_id, gross_amount, commission_amount, net_amount)
      select sid, b.id,
             b.paid_amount - b.refunded_amount,
             least(b.commission_amount, b.paid_amount - b.refunded_amount),
             greatest(b.paid_amount - b.refunded_amount - b.commission_amount, 0)
        from public.bookings b
       where b.id = any(row.bookings);

      -- ومقدّم الخدمة يُخبَر: مستحقٌّ لا يعلم به صاحبه لا يُطمئنه.
      perform public.notify_provider(
        row.provider_id, 'payment', 'صدرت تسوية مستحقّاتك',
        'صافي مستحقّك عن الفترة: ' || to_char(gross - comm, 'FM999G999G999') || ' ر.ي.',
        jsonb_build_object('settlement_id', sid)
      );

      made := made + 1;
    end;
  end loop;

  return made;
end $$;

comment on function public.api_admin_build_settlements(date, date) is
  'يحتسب تسويات فترةٍ من الحجوزات المنفَّذة المقبوضة. لا يحتسب حجزاً مرّتين.';

revoke all on function public.api_admin_build_settlements(date, date) from public, anon;
grant execute on function public.api_admin_build_settlements(date, date) to authenticated;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'دالّة الاحتساب' as البند,
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_admin_build_settlements')
       then '✅' else '❌' end as الحال
union all
select 'حجوزاتٌ منفَّذة بلا تسوية',
       coalesce((select count(*)::text from public.bookings b
                  where b.status = 'completed'
                    and b.paid_amount > b.refunded_amount
                    and not exists (select 1 from public.settlement_items i
                                     where i.booking_id = b.id)), '0');
