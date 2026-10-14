-- Apply after backend.sql, before backend-publish.sql and backend-safety.sql.
-- Owner email mapping lives only in cherry_private.owner_binding, never in public content.
begin;
create function public.cherry_identity() returns jsonb language sql stable security invoker set search_path='' as $$select jsonb_build_object('memberId',cherry_private.current_member(),'admin',cherry_private.is_admin());$$;
revoke all on function public.cherry_identity() from public;
grant execute on function public.cherry_identity() to authenticated;
alter table public.cherry_records add column deleted_at timestamptz;
alter policy records_read on public.cherry_records using(deleted_at is null);
create table public.cherry_access_requests(user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,member_id text not null,created_at timestamptz not null default now());
alter table public.cherry_access_requests enable row level security;
revoke all on public.cherry_access_requests from anon,authenticated;
grant select,insert,update on public.cherry_access_requests to authenticated;
create policy requests_select on public.cherry_access_requests for select to authenticated using(user_id=(select auth.uid()) or (select cherry_private.is_admin()));
create policy requests_insert on public.cherry_access_requests for insert to authenticated with check(user_id=(select auth.uid()));
create policy requests_update on public.cherry_access_requests for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create function cherry_private.request_list() returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
  return(select coalesce(jsonb_agg(jsonb_build_object('userId',r.user_id,'memberId',r.member_id,'email',u.email,'verified',u.email_confirmed_at is not null,'registered',m.member_id)),'[]'::jsonb) from public.cherry_access_requests r join auth.users u on u.id=r.user_id left join cherry_private.memberships m on m.user_id=r.user_id);
end;$$;
create function cherry_private.register_member(p_user uuid,p_member text) returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
  if not exists(select 1 from auth.users where id=p_user and email_confirmed_at is not null) then raise exception '이메일 인증을 먼저 완료해주세요';end if;
  if not exists(select 1 from public.cherry_content c,jsonb_array_elements(c.document->'members') m where m->>'id'=p_member) then raise exception '등록된 멤버 이름을 선택해주세요';end if;
  if exists(select 1 from cherry_private.memberships where user_id=p_user and is_admin) then raise exception '방장 계정은 변경할 수 없습니다';end if;
  insert into cherry_private.memberships(user_id,member_id) values(p_user,p_member) on conflict(user_id) do update set member_id=excluded.member_id,active=true;
end;$$;
revoke all on function cherry_private.request_list() from public;
revoke all on function cherry_private.register_member(uuid,text) from public;
grant execute on function cherry_private.request_list() to authenticated;
grant execute on function cherry_private.register_member(uuid,text) to authenticated;
create function public.cherry_request_list() returns jsonb language sql security invoker set search_path='' as $$select cherry_private.request_list();$$;
create function public.cherry_register_member(p_user uuid,p_member text) returns void language sql security invoker set search_path='' as $$select cherry_private.register_member(p_user,p_member);$$;
revoke all on function public.cherry_request_list() from public;
revoke all on function public.cherry_register_member(uuid,text) from public;
grant execute on function public.cherry_request_list() to authenticated;
grant execute on function public.cherry_register_member(uuid,text) to authenticated;
create table cherry_private.owner_binding(email text primary key,member_id text not null);
alter table cherry_private.owner_binding enable row level security;
create function cherry_private.bind_owner() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.email_confirmed_at is not null then insert into cherry_private.memberships(user_id,member_id,is_admin) select new.id,member_id,true from cherry_private.owner_binding where email=lower(new.email) on conflict(user_id) do nothing;end if;
  return new;
end;$$;
revoke all on function cherry_private.bind_owner() from public;
create trigger cherry_owner_binding after insert or update of email_confirmed_at on auth.users for each row execute function cherry_private.bind_owner();
commit;
