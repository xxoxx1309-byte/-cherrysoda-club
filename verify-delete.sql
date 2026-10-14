begin;
insert into auth.users(id,email,email_confirmed_at) values
('66666666-6666-4666-8666-666666666666','cherry-delete@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id) values
('66666666-6666-4666-8666-666666666666','yuki');
insert into public.cherry_records(id,member_id,user_id,title,date,kind) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','yuki','66666666-6666-4666-8666-666666666666','delete fixture',current_date,'free');
set local role authenticated;
set local request.jwt.claim.sub='66666666-6666-4666-8666-666666666666';
update public.cherry_records set deleted_at=now() where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' returning id;
do $$begin if not exists(select 1 from public.cherry_records where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' and deleted_at is not null) then raise exception 'owner cannot read deleted record';end if;end;$$;
set local request.jwt.claim.sub='77777777-7777-4777-8777-777777777777';
do $$begin if exists(select 1 from public.cherry_records where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd') then raise exception 'deleted record leaked to another user';end if;end;$$;
reset role;
set local role anon;
do $$begin if exists(select 1 from public.cherry_records where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd') then raise exception 'deleted record leaked publicly';end if;end;$$;
reset role;
select 'soft delete works; deleted record hidden from public and other users' as result;
rollback;
