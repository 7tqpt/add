// جردٌ كامل للقاعدة — يُبنى المخطَّط في Postgres حقيقي ثم تُستجوَب فهارسه.
//
// الفرق بين هذا وبين قراءة ملفات SQL بالعين: ما يخرج هنا هو ما تنتجه القاعدة
// فعلاً بعد تنفيذ الملفات بترتيبها، لا ما نظنّه مكتوباً فيها.
//
//   node inventory.mjs > ../../<وجهة>/inventory.json
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

// ما توفّره Supabase ولا يوجد في Postgres عارياً.
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon;
  create role authenticated;
  create schema if not exists storage;
  create table storage.buckets (
    id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`)

const order = ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql', 'storage.sql']
const loaded = []
for (const f of order) {
  await db.exec(read(f))
  loaded.push({ file: f, lines: read(f).split('\n').length })
}

const q = async (sql) => (await db.query(sql)).rows

const tables = await q(`
  select c.relname as name, c.relrowsecurity as rls,
         (select count(*) from information_schema.columns
           where table_schema='public' and table_name=c.relname) as cols,
         obj_description(c.oid) as note
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r'
   order by c.relname`)

// عدد الصفوف لكل جدول — يحتاج استعلاماً لكل جدول، ولا سبيل إلى تعميمه.
for (const t of tables) {
  t.rows = Number((await q(`select count(*)::int as n from public."${t.name}"`))[0].n)
  t.policies = Number(
    (await q(`select count(*)::int as n from pg_policies where schemaname='public' and tablename='${t.name}'`))[0].n,
  )
  t.indexes = Number(
    (await q(`select count(*)::int as n from pg_indexes where schemaname='public' and tablename='${t.name}'`))[0].n,
  )
}

const out = {
  loaded,
  tables,
  views: await q(`
    select c.relname as name,
           (c.reloptions::text like '%security_invoker=true%') as invoker
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relkind='v' order by c.relname`),
  functions: await q(`
    select p.proname as name,
           pg_get_function_arguments(p.oid) as args,
           pg_get_function_result(p.oid) as returns,
           p.prosecdef as definer
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' order by p.proname`),
  policies: await q(`
    select tablename as tbl, policyname as name, cmd, roles::text as roles
      from pg_policies where schemaname='public' order by tablename, policyname`),
  foreignKeys: await q(`
    select con.conrelid::regclass::text as child,
           con.confrelid::regclass::text as parent,
           con.conname as name,
           case con.confdeltype when 'c' then 'cascade' when 'n' then 'set null'
                when 'r' then 'restrict' when 'a' then 'no action' else con.confdeltype::text end as on_delete
      from pg_constraint con join pg_namespace n on n.oid=con.connamespace
     where n.nspname='public' and con.contype='f' order by child, parent`),
  checks: await q(`
    select con.conrelid::regclass::text as tbl, con.conname as name,
           pg_get_constraintdef(con.oid) as def
      from pg_constraint con join pg_namespace n on n.oid=con.connamespace
     where n.nspname='public' and con.contype='c' order by tbl, name`),
  triggers: await q(`
    select c.relname as tbl, t.tgname as name
      from pg_trigger t join pg_class c on c.oid=t.tgrelid
      join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and not t.tgisinternal order by c.relname, t.tgname`),
  enums: await q(`
    select t.typname as name, array_agg(e.enumlabel order by e.enumsortorder)::text as labels
      from pg_type t join pg_enum e on e.enumtypid=t.oid
      join pg_namespace n on n.oid=t.typnamespace
     where n.nspname='public' group by t.typname order by t.typname`),
  buckets: await q(`select id, public, file_size_limit, allowed_mime_types::text from storage.buckets`),
  storagePolicies: await q(`
    select policyname as name, cmd from pg_policies
     where schemaname='storage' order by policyname`),
}

console.log(JSON.stringify(out, null, 2))
