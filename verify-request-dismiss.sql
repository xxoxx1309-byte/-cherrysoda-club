begin;
insert into auth.users(id,email,email_confirmed_at) values
('55555555-5555-4555-8555-555555555551','cherry-request-a@example.invalid',now()),
('55555555-5555-4555-8555-555555555552','cherry-request-b@example.invalid',now()),
('55555555-5555-4555-8555-555555555553','cherry-request-owner@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id,is_admin) values
('55555555-5555-4555-8555-555555555552','__request_member_test',false),
('55555555-5555-4555-8555-555555555553','__request_admin_test',true);
insert into public.cherry_access_requests(user_id,member_id) values
('55555555-5555-4555-8555-555555555551','yuki'),
('55555555-5555-4555-8555-555555555552','cold');
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-4555-8555-555555555551';
do $$declare n int;begin
 update public.cherry_access_requests set dismissed_at=now() where user_id='55555555-5555-4555-8555-555555555551';get diagnostics n=row_count;if n<>1 then raise exception 'self cancel failed';end if;
 update public.cherry_access_requests set dismissed_at=now() where user_id='55555555-5555-4555-8555-555555555552';get diagnostics n=row_count;if n<>0 then raise exception 'other user update allowed';end if;
 update public.cherry_access_requests set dismissed_at=null where user_id='55555555-5555-4555-8555-555555555551';get diagnostics n=row_count;if n<>1 then raise exception 'resubmit failed';end if;
end;$$;
set local request.jwt.claim.sub='55555555-5555-4555-8555-555555555553';
do $$declare n int;begin
 update public.cherry_access_requests set dismissed_at=now() where user_id in('55555555-5555-4555-8555-555555555551','55555555-5555-4555-8555-555555555552');get diagnostics n=row_count;if n<>2 then raise exception 'owner dismiss failed';end if;
 if exists(select 1 from jsonb_array_elements(public.cherry_request_list()) x where x->>'userId' in('55555555-5555-4555-8555-555555555551','55555555-5555-4555-8555-555555555552')) then raise exception 'dismissed request still listed';end if;
end;$$;
reset role;
do $$begin if not exists(select 1 from cherry_private.memberships where user_id='55555555-5555-4555-8555-555555555552' and active) then raise exception 'member permission changed';end if;end;$$;
select 'PASS: self cancel, resubmit, owner dismiss, other-user protection, hidden list, membership preserved' as verification;
rollback;
