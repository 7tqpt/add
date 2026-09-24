-- Run once on an existing database to close exposed notification RPCs without
-- reapplying api.sql or other feature migrations. Safe to run again.
do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.notify_user(uuid,text,text,text,jsonb)',
    'public.notify_provider(uuid,text,text,text,jsonb)',
    'public.broadcast_audience(text)',
    'public.enable_push_webhook(text)',
    'public.disable_push_webhook()',
    'public.dispatch_push_webhook()'
  ] loop
    if to_regprocedure(signature) is not null then
      execute format('revoke all on function %s from public, anon, authenticated', signature);
    end if;
  end loop;
end $$;
