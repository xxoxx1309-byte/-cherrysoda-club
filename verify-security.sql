-- All fixtures and writes are rolled back; no test account or record persists.
begin;
create temporary table cherry_checks(test text,passed boolean);
grant all on cherry_checks to anon,authenticated;
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','cherry-a@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','cherry-b@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','cherry-outsider@example.invalid',now()),
('44444444-4444-4444-8444-444444444444','cherry-admin@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id,is_admin) values
('11111111-1111-4111-8111-111111111111','yuki',false),
('22222222-2222-4222-8222-222222222222','cold',false),
('44444444-4444-4444-8444-444444444444','myo',true);
set local role anon;
do $$begin
  begin insert into public.cherry_records(member_id,user_id,title,date,kind) values('yuki','11111111-1111-4111-8111-111111111111','test',current_date,'free');
    insert into cherry_checks values('anon write denied',false);
  exception when insufficient_privilege then insert into cherry_checks values('anon write denied',true); end;
end;$$;
reset role;
set local role authenticated;
set local request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
insert into public.cherry_records(id,member_id,title,date,kind) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','yuki','A original',current_date,'free');
insert into cherry_checks values('member own insert',true);
update public.cherry_records set title='A edited' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into cherry_checks select 'member own update',title='A edited' from public.cherry_records where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
do $$begin
  begin update public.cherry_records set member_id='cold' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    insert into cherry_checks values('ownership transfer denied',false);
  exception when insufficient_privilege then insert into cherry_checks values('ownership transfer denied',true); end;
  begin perform public.cherry_publish('{}'::jsonb,1);
    insert into cherry_checks values('member admin API denied',false);
  exception when raise_exception then insert into cherry_checks values('member admin API denied',true); end;
end;$$;
set local request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$declare n integer;begin
  update public.cherry_records set title='B attack' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';get diagnostics n=row_count;
  insert into cherry_checks values('other member update denied',n=0);
  delete from public.cherry_records where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';get diagnostics n=row_count;
  insert into cherry_checks values('other member delete denied',n=0);
end;$$;
set local request.jwt.claim.sub='33333333-3333-4333-8333-333333333333';
do $$begin
  begin insert into public.cherry_records(member_id,title,date,kind) values('cold','outsider',current_date,'free');
    insert into cherry_checks values('nonmember insert denied',false);
  exception when insufficient_privilege then insert into cherry_checks values('nonmember insert denied',true); end;
end;$$;
set local request.jwt.claim.sub='44444444-4444-4444-8444-444444444444';
update public.cherry_records set title='admin edited' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into cherry_checks select 'admin manages member record',title='admin edited' from public.cherry_records where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
do $$begin if exists(select 1 from cherry_checks where not passed) or (select count(*) from cherry_checks)<>9 then raise exception 'security checks failed';end if;end;$$;
select * from cherry_checks;
rollback;
