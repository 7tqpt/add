import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'
import { buildInstall, buildHardening } from '../../tool/security_sql.mjs'

const read = f => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')

test('bundled installation and migration match the canonical SQL', () => {
  assert.equal(read('install.sql').trimEnd(), buildInstall().trimEnd())
  assert.equal(read('security_hardening.sql').trimEnd(), buildHardening().trimEnd())
})

test('security boundaries hold for actual authenticated roles', async t => {
  const db = new PGlite()
  t.after(() => db.close())
  await db.exec(`
    create schema auth;
    create table auth.users (id uuid primary key, email text);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.uid', true), '')::uuid $$;
    create role anon; create role authenticated;
    create schema storage;
    create table storage.buckets (id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
    create function storage.foldername(p text) returns text[] language sql immutable
      as $$ select string_to_array(p, '/') $$;
  `)
  for (const f of ['install.sql', 'support.sql', 'roles.sql', 'profile.sql', 'service_media.sql',
    'chat.sql', 'chat_media.sql', 'payments_app.sql', 'availability.sql', 'plan_tasks.sql',
    'coupons.sql', 'phone_verify.sql', 'completion_review.sql']) await db.exec(read(f))

  const ids = Object.fromEntries(['customer', 'provider', 'owner', 'finance', 'support', 'moderator', 'viewer', 'newuser']
    .map(role => [role, crypto.randomUUID()]))
  for (const [role, id] of Object.entries(ids)) {
    await db.query('insert into auth.users values ($1,$2)', [id, `${role}@security.test`])
    if (['owner', 'finance', 'support', 'moderator', 'viewer'].includes(role)) {
      await db.query('insert into public.admins(user_id,email,role) values ($1,$2,$3)', [id, `${role}@security.test`, role])
    }
  }
  const as = async (who, sql, params = []) => {
    await db.query("select set_config('test.uid', $1, false)", [ids[who] ?? ''])
    await db.exec(who === 'anon' ? 'set role anon' : 'set role authenticated')
    try { return await db.query(sql, params) }
    finally {
      await db.exec('reset role')
      await db.query("select set_config('test.uid', '', false)")
    }
  }
  const one = async (sql, params = []) => (await db.query(sql, params)).rows[0]
  const app = {}
  for (const who of ['customer', 'provider']) {
    app[who] = (await as(who, 'select * from public.api_register_profile($1)', [who])).rows[0].id
  }
  const category = await one("insert into public.service_categories(name,slug) values ('قاعة','security-hall') returning id")
  const provider = await one(`insert into public.service_providers
    (user_id,full_name,email,business_name,status,verified_at) values ($1,'مزود','provider@security.test','قاعة','verified',now()) returning id`, [app.provider])
  const service = await one(`insert into public.provider_services(provider_id,category_id,title,price,deposit_percent)
    values ($1,$2,'خدمة الاختبار',1000,30) returning id`, [provider.id, category.id])

  // Simulate vulnerable policies on an already installed database.
  await db.exec(`create policy users_self_update on public.app_users for update to authenticated
    using(auth_user_id=auth.uid()) with check(auth_user_id=auth.uid());
    create policy users_self_insert on public.app_users for insert to authenticated with check(auth_user_id=auth.uid());
    create policy availability_owner_write on public.provider_availability for all to authenticated
    using(provider_id=public.current_provider()) with check(provider_id=public.current_provider());`)
  const completionBefore = await one("select pg_get_functiondef('public.api_complete_booking(uuid)'::regprocedure) as definition")
  const permissionsBefore = await one('select jsonb_agg(x order by role,area) as matrix from public.admin_areas x')
  await db.exec(read('security_hardening.sql'))
  await db.exec(read('security_hardening.sql'))
  // Negative controls alter only this disposable database, never source/production.
  const mutations = {
    account: `create policy users_self_update on public.app_users for update to authenticated
      using(auth_user_id=auth.uid()) with check(auth_user_id=auth.uid());`,
    finance: read('payments_app.sql').replaceAll("can_write_area('finance')", 'can_write()'),
    booking: read('coupons.sql').replaceAll("can_write_area('bookings')", 'can_write()'),
    phone: `create or replace function public.current_app_user() returns uuid language sql stable
      security definer set search_path=public as $$
      select id from public.app_users where auth_user_id=auth.uid() limit 1 $$;`,
    availability: `create policy availability_owner_write on public.provider_availability for all to authenticated
      using(provider_id=public.current_provider()) with check(provider_id=public.current_provider());`,
    uniqueness: 'drop index public.bookings_confirmed_provider_day_key;',
    viewer: `drop policy plans_owner on public.wedding_plans;
      create policy plans_owner on public.wedding_plans for all to authenticated
      using(public.is_admin() or user_id=public.current_app_user())
      with check(public.is_admin() or user_id=public.current_app_user());`,
    audit: 'drop trigger audit_accept_server_entry on public.audit_log;',
  }
  if (process.env.SECURITY_MUTATION) {
    assert.ok(Object.hasOwn(mutations, process.env.SECURITY_MUTATION), 'unknown mutation')
    await db.exec(mutations[process.env.SECURITY_MUTATION])
  }
  assert.deepEqual(await one('select jsonb_agg(x order by role,area) as matrix from public.admin_areas x'), permissionsBefore)
  assert.deepEqual(await one("select pg_get_functiondef('public.api_complete_booking(uuid)'::regprocedure) as definition"), completionBefore)

  await t.test('self-service cannot set account status or phone verification', async () => {
    await db.query("update public.app_users set status='suspended' where id=$1", [app.customer])
    const changed = await as('customer', "update public.app_users set status='active',phone_verified_at=now() where id=$1 returning id", [app.customer])
    assert.equal(changed.rows.length, 0)
    assert.equal((await one('select status from public.app_users where id=$1', [app.customer])).status, 'suspended')
    await assert.rejects(as('newuser', `insert into public.app_users(auth_user_id,full_name,email,status,phone_verified_at)
      values ($1,'forged','forged@security.test','active',now())`, [ids.newuser]), /row-level security/)
    await as('customer', "select public.api_update_profile('اسم جديد')")
    assert.equal((await one('select full_name from public.app_users where id=$1', [app.customer])).full_name, 'اسم جديد')
    await as('owner', "update public.app_users set status='active' where id=$1", [app.customer])
    assert.equal((await one('select status from public.app_users where id=$1', [app.customer])).status, 'active')
  })

  const booking = async offset => (await as('customer',
    'select * from public.api_create_booking($1,current_date+$2::integer)', [service.id, offset])).rows[0]
  const first = await booking(100)
  const second = await booking(100)
  const payment = await one("select id from public.payments where booking_id=$1 and status='pending'", [first.id])

  await t.test('non-finance writers cannot confirm, reject, refund or inspect payments', async () => {
    for (const who of ['customer', 'support', 'moderator', 'viewer']) {
      for (const fn of ['api_admin_confirm_payment', 'api_admin_reject_payment', 'api_admin_refund_payment', 'api_refund_outlook']) {
        await assert.rejects(as(who, `select public.${fn}($1)`, [payment.id]), /صلاحية/)
      }
    }
    assert.equal((await as('finance', 'select * from public.api_admin_confirm_payment($1)', [payment.id])).rows[0].status, 'paid')
    assert.equal(Number((await one('select paid_amount from public.bookings where id=$1', [first.id])).paid_amount), 300)
    await as('finance', 'select public.api_admin_refund_payment($1)', [payment.id])
    assert.equal((await one('select status from public.payments where id=$1', [payment.id])).status, 'refunded')
  })

  await t.test('booking and support RPCs enforce their own areas', async () => {
    for (const who of ['support', 'finance', 'moderator', 'viewer']) {
      await assert.rejects(as(who, 'select public.api_cancel_booking($1)', [first.id]), /صلاحية/)
      await assert.rejects(as(who, 'select public.api_respond_to_booking($1,true)', [first.id]), /صلاحية/)
    }
    await assert.rejects(as('finance', "select public.admin_reply_ticket($1,'reply',false,null)", [crypto.randomUUID()]), /صلاحية/)
    const changed = await as('support', "update public.provider_services set price=1 where id=$1 returning id", [service.id])
    assert.equal(changed.rows.length, 0)
  })

  await t.test('confirmed days cannot be opened or double-booked through direct writes', async () => {
    await as('provider', 'select public.api_respond_to_booking($1,true)', [first.id])
    assert.equal((await as('provider', 'delete from public.provider_availability where provider_id=$1 returning id', [provider.id])).rows.length, 0)
    // A pre-existing manual note must not defeat the authoritative bookings check.
    await db.query("update public.provider_availability set note='سفر' where provider_id=$1", [provider.id])
    await assert.rejects(as('provider', 'select public.api_set_availability(current_date+100,false)'), /محجوز/)
    await assert.rejects(as('provider', 'select public.api_respond_to_booking($1,true)', [second.id]), /محجوز/)
    await assert.rejects(as('owner', "update public.bookings set status='confirmed',confirmed_at=now() where id=$1", [second.id]), /bookings_confirmed_provider_day_key/)
    assert.equal((await one('select status from public.bookings where id=$1', [second.id])).status, 'pending_provider')
    await as('provider', 'select public.api_set_availability(current_date+101,true)')
    await as('provider', 'select public.api_set_availability(current_date+101,false)')
  })

  await t.test('phone gate applies to RPCs and private data but permits profile/OTP recovery', async () => {
    await db.exec('update public.app_settings set require_phone_verification=true where id=1')
    assert.equal((await as('customer', 'select public.current_app_user() as id')).rows[0].id, null)
    assert.equal((await as('provider', 'select public.current_provider() as id')).rows[0].id, null)
    assert.equal((await as('customer', 'select * from public.bookings')).rows.length, 0)
    await assert.rejects(booking(102), /تسجيل الدخول/)
    await as('customer', "select public.api_update_profile('اسم موثوق', '+967770000001')")
    assert.equal((await as('customer', 'select * from public.api_my_profile()')).rows.length, 1)
    await assert.rejects(as('customer', 'select public.otp_mark_verified($1,$2)', [ids.customer, '+967770000001']), /permission denied/)
    await db.query('select public.otp_mark_verified($1,$2)', [ids.customer, '+967770000001'])
    assert.equal((await as('customer', 'select public.current_app_user() as id')).rows[0].id, app.customer)
    assert.ok((await booking(102)).id)
    await as('customer', "select public.api_update_profile('اسم موثوق', '+967770000002')")
    assert.equal((await as('customer', 'select public.current_app_user() as id')).rows[0].id, null)
    await db.exec('update public.app_settings set require_phone_verification=false where id=1')
  })

  await t.test('viewer cannot delete records using a read policy', async () => {
    const plan = await one("insert into public.wedding_plans(user_id,title,wedding_date) values ($1,'خطة',current_date+200) returning id", [app.customer])
    const device = await one("insert into public.user_devices(user_id,model,platform) values ($1,'test','android') returning id", [app.customer])
    for (const [table, id] of [['wedding_plans', plan.id], ['user_devices', device.id]]) {
      assert.equal((await as('viewer', `delete from public.${table} where id=$1 returning id`, [id])).rows.length, 0)
      assert.ok(await one(`select id from public.${table} where id=$1`, [id]))
    }
    assert.equal((await as('viewer', 'delete from public.plan_tasks where plan_id=$1 returning id', [plan.id])).rows.length, 0)
    await assert.rejects(as('anon', 'select public.seed_plan_tasks($1)', [plan.id]), /permission denied/)
    await assert.rejects(as('customer', 'select public.seed_plan_tasks($1)', [plan.id]), /permission denied/)
  })

  await t.test('audit entries come from actual changes and cannot impersonate another actor', async () => {
    const before = await one('select count(*)::int as n from public.audit_log')
    await as('support', `insert into public.audit_log(actor_email,action,entity,entity_label)
      values ('owner@security.test','admin.ownership','admin','forged')`)
    assert.deepEqual(await one('select count(*)::int as n from public.audit_log'), before)
    await as('owner', "update public.app_users set status='suspended' where id=$1", [app.customer])
    const row = await one("select * from public.audit_log where entity_id=$1 order by created_at desc limit 1", [app.customer])
    assert.equal(row.actor_email, 'owner@security.test')
    assert.equal(row.details.source, 'database')
    assert.equal(row.details.actor_user_id, ids.owner)
    assert.ok(row.details.changed_fields.includes('status'))
    assert.equal(row.details.phone, undefined)
    await as('owner', 'select public.api_clear_audit_log()')
    assert.equal((await one('select count(*)::int as n from public.audit_log')).n, 1)
    assert.equal((await one('select action from public.audit_log')).action, 'audit.purge')
  })
})
