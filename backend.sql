-- Cherry Soda Club. Review before execution on aqessidqzmekfigbglkc.
-- Admin identity must be bound to a verified auth.users account by the owner.
begin;
create schema if not exists cherry_private;
revoke all on schema cherry_private from public, anon, authenticated;
create table cherry_private.memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  member_id text not null unique,
  is_admin boolean not null default false,
  active boolean not null default true
);
alter table cherry_private.memberships enable row level security;
create function cherry_private.current_member() returns text
language sql stable security definer set search_path = '' as $$
  select member_id from cherry_private.memberships
  where user_id = (select auth.uid()) and active and auth.uid() is not null;
$$;
create function cherry_private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select is_admin from cherry_private.memberships
  where user_id = (select auth.uid()) and active and auth.uid() is not null),false);
$$;
revoke all on function cherry_private.current_member() from public;
revoke all on function cherry_private.is_admin() from public;
grant usage on schema cherry_private to authenticated;
grant execute on function cherry_private.current_member() to authenticated;
grant execute on function cherry_private.is_admin() to authenticated;

create table public.cherry_content (
  id integer primary key check(id = 1),
  document jsonb not null check(jsonb_typeof(document) = 'object'),
  revision bigint not null default 1
);
alter table public.cherry_content enable row level security;
revoke all on public.cherry_content from anon, authenticated;
grant select on public.cherry_content to anon, authenticated;
grant insert, update on public.cherry_content to authenticated;
create policy content_read on public.cherry_content for select to anon, authenticated using(true);
create policy content_insert on public.cherry_content for insert to authenticated
  with check((select cherry_private.is_admin()));
create policy content_update on public.cherry_content for update to authenticated
  using((select cherry_private.is_admin())) with check((select cherry_private.is_admin()));

create table public.cherry_records (
  id uuid primary key default gen_random_uuid(),
  member_id text not null,
  user_id uuid not null default auth.uid() references auth.users(id),
  title text not null check(length(title) between 1 and 150),
  date date not null,
  kind text not null check(kind in ('theme','free','meetup')),
  theme_id text,
  description text not null default '' check(length(description) <= 5000),
  images jsonb not null default '[]' check(jsonb_typeof(images)='array' and jsonb_array_length(images) <= 6),
  tags jsonb not null default '[]' check(jsonb_typeof(tags)='array' and jsonb_array_length(tags) <= 15),
  created_at timestamptz not null default now()
);
create index cherry_records_member_date on public.cherry_records(member_id,date desc);
create index cherry_records_user on public.cherry_records(user_id);
alter table public.cherry_records enable row level security;
revoke all on public.cherry_records from anon, authenticated;
grant select(id,member_id,title,date,kind,theme_id,description,images,tags,created_at) on public.cherry_records to anon, authenticated;
grant insert, update, delete on public.cherry_records to authenticated;
create policy records_read on public.cherry_records for select to anon, authenticated using(true);
create policy records_insert on public.cherry_records for insert to authenticated with check (
  user_id=(select auth.uid()) and member_id=(select cherry_private.current_member())
);
create policy records_update on public.cherry_records for update to authenticated using (
  (select cherry_private.is_admin()) or (user_id=(select auth.uid()) and member_id=(select cherry_private.current_member()))
) with check (
  (select cherry_private.is_admin()) or (user_id=(select auth.uid()) and member_id=(select cherry_private.current_member()))
);
create policy records_delete on public.cherry_records for delete to authenticated using (
  (select cherry_private.is_admin()) or (user_id=(select auth.uid()) and member_id=(select cherry_private.current_member()))
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('cherry-images','cherry-images',true,10485760,array['image/jpeg','image/png','image/webp']);
create policy cherry_images_read on storage.objects for select to authenticated using(bucket_id='cherry-images' and ((select cherry_private.is_admin()) or ((storage.foldername(name))[1]=(select auth.uid())::text and (select cherry_private.current_member()) is not null)));
create policy cherry_images_insert on storage.objects for insert to authenticated with check(
  bucket_id='cherry-images' and (storage.foldername(name))[1]=(select auth.uid())::text
  and (select cherry_private.current_member()) is not null
);
create policy cherry_images_update on storage.objects for update to authenticated using(
  bucket_id='cherry-images' and ((select cherry_private.is_admin()) or (
    (storage.foldername(name))[1]=(select auth.uid())::text and (select cherry_private.current_member()) is not null))
) with check(
  bucket_id='cherry-images' and ((select cherry_private.is_admin()) or (
    (storage.foldername(name))[1]=(select auth.uid())::text and (select cherry_private.current_member()) is not null))
);
create policy cherry_images_delete on storage.objects for delete to authenticated using(
  bucket_id='cherry-images' and ((select cherry_private.is_admin()) or (
    (storage.foldername(name))[1]=(select auth.uid())::text and (select cherry_private.current_member()) is not null))
);
commit;
