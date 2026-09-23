-- سجل العمليات من تغييرات القاعدة الفعلية. شغّل بعد roles.sql.
-- security_hardening.sql يحتوي نسخة من هذا الملف للقواعد القائمة.
begin;

-- تبقى نداءات recordAudit القديمة متوافقة: تُهمل الصفوف القادمة مباشرة من
-- المتصفح، ويكتب مشغّل الجدول الحدث الحقيقي في المعاملة نفسها.
-- SECURITY INVOKER مقصودة: current_user يميّز نداء API المباشر عن الدالة
-- الموثوقة التي تعمل بصلاحية مالكها. لا يقبل العميل اختيار كاتب السجل.
create or replace function public.audit_accept_server_entry()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') then
    return null;
  end if;
  if auth.uid() is not null then
    new.actor_email := coalesce((select u.email from auth.users u where u.id = auth.uid()), '');
    new.created_at := clock_timestamp();
    new.details := coalesce(new.details, '{}'::jsonb)
      || jsonb_build_object('source', 'database', 'actor_user_id', auth.uid());
  end if;
  return new;
end;
$$;

drop trigger if exists audit_accept_server_entry on public.audit_log;
create trigger audit_accept_server_entry before insert on public.audit_log
  for each row execute function public.audit_accept_server_entry();

create or replace function public.audit_admin_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  row_data jsonb;
  previous jsonb;
  changed jsonb;
  entity_name text := tg_argv[0];
begin
  row_data := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  previous := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  if actor is null then return null; end if;
  if not public.is_admin()
     and not (tg_table_name = 'admins' and tg_op = 'DELETE'
              and row_data ->> 'user_id' = actor::text) then
    return null;
  end if;
  if tg_op = 'UPDATE' and row_data = previous then return null; end if;

  -- أسماء الحقول وحدها؛ لا ننسخ رسائل الناس أو أرقامهم أو المستندات إلى السجل.
  select coalesce(jsonb_agg(k order by k), '[]'::jsonb) into changed
    from jsonb_object_keys(row_data) as fields(k)
   where tg_op <> 'UPDATE' or row_data -> k is distinct from previous -> k;

  insert into public.audit_log
    (actor_email, action, entity, entity_id, entity_label, details)
  values (
    coalesce((select u.email from auth.users u where u.id = actor), ''),
    case tg_op when 'INSERT' then 'إضافة سجل'
               when 'UPDATE' then 'تعديل سجل' else 'حذف سجل' end,
    entity_name,
    coalesce(row_data ->> 'id', row_data ->> 'user_id', row_data ->> 'role', ''),
    coalesce(row_data ->> 'reference', row_data ->> 'business_name',
             row_data ->> 'full_name', row_data ->> 'title', row_data ->> 'name',
             row_data ->> 'id', tg_table_name),
    jsonb_build_object('source', 'database', 'table', tg_table_name,
                       'operation', tg_op, 'changed_fields', changed)
  );
  return null;
end;
$$;

revoke all on function public.audit_accept_server_entry() from public, anon, authenticated;
revoke all on function public.audit_admin_change() from public, anon, authenticated;

do $$
declare target record;
begin
  for target in select * from (values
    ('app_users', 'user'), ('service_providers', 'provider'),
    ('provider_documents', 'provider'), ('provider_categories', 'provider'),
    ('provider_services', 'service'), ('service_media', 'service'),
    ('bookings', 'booking'), ('wedding_plans', 'plan'), ('plan_tasks', 'plan'),
    ('payments', 'payment'), ('invoices', 'payment'),
    ('settlements', 'settlement'), ('settlement_items', 'settlement'),
    ('provider_subscriptions', 'subscription'), ('subscription_plans', 'subscription'),
    ('promotions', 'promotion'), ('coupons', 'coupon'),
    ('reviews', 'review'), ('disputes', 'dispute'), ('dispute_messages', 'dispute'),
    ('support_tickets', 'support'), ('support_messages', 'support'),
    ('push_notifications', 'notification'), ('app_versions', 'version'),
    ('app_settings', 'settings'), ('service_categories', 'category'),
    ('governorates', 'settings'), ('cancellation_policies', 'policy'),
    ('admins', 'admin'), ('admin_invitations', 'admin'), ('admin_areas', 'admin')
  ) as targets(table_name, entity)
  loop
    if to_regclass('public.' || target.table_name) is not null then
      execute format('drop trigger if exists audit_admin_change on public.%I', target.table_name);
      execute format('create trigger audit_admin_change after insert or update or delete on public.%I
        for each row execute function public.audit_admin_change(%L)', target.table_name, target.entity);
    end if;
  end loop;
end;
$$;

commit;
