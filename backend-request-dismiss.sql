-- Hide requests without deleting accounts, memberships, or request history.
begin;
alter table public.cherry_access_requests add column if not exists dismissed_at timestamptz;
alter policy requests_update on public.cherry_access_requests
 using(user_id=(select auth.uid()) or (select cherry_private.is_admin()))
 with check(user_id=(select auth.uid()) or (select cherry_private.is_admin()));
create or replace function cherry_private.request_list() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
 return(select coalesce(jsonb_agg(jsonb_build_object('userId',r.user_id,'memberId',r.member_id,'email',u.email,'verified',u.email_confirmed_at is not null,'registered',m.member_id) order by r.created_at),'[]'::jsonb)
 from public.cherry_access_requests r join auth.users u on u.id=r.user_id
 left join cherry_private.memberships m on m.user_id=r.user_id where r.dismissed_at is null);
end;$$;
commit;
