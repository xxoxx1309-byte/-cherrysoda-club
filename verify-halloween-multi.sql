-- Transaction-only fixtures; restores the actual event state on completion.
begin;
update cherry_private.halloween_event set phase='collecting' where id=1;
insert into auth.users(id,email,email_confirmed_at) values('66666666-6666-4666-8666-666666666661','halloween-multi-test@example.invalid',now()),('66666666-6666-4666-8666-666666666662','halloween-other-test@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id) values('66666666-6666-4666-8666-666666666661','__multi_test'),('66666666-6666-4666-8666-666666666662','__multi_other');
insert into cherry_private.halloween_missions(id,label) select coalesce(max(id),0)+100,'__test mission A' from cherry_private.halloween_missions;
insert into cherry_private.halloween_missions(id,label) select coalesce(max(id),0)+100,'__test mission B' from cherry_private.halloween_missions;
set local role authenticated;
set local request.jwt.claim.sub='66666666-6666-4666-8666-666666666661';
do $test$
declare s jsonb; first_id text; second_id text; blocked boolean:=false;
begin
 s:=public.cherry_halloween('join');first_id:=s#>>'{mine,id}';
 if jsonb_array_length(s->'myEntries')<>1 then raise exception 'first assignment failed';end if;
 begin perform public.cherry_halloween('next_mission');exception when raise_exception then blocked:=true;end;
 if not blocked then raise exception 'unfinished mission allowed another';end if;
 s:=public.cherry_halloween('submit',jsonb_build_object('entry',first_id,'title','test first','image','data:image/png;base64,AAAA'));
 s:=public.cherry_halloween('next_mission');second_id:=s#>>'{mine,id}';
 if first_id=second_id or jsonb_array_length(s->'myEntries')<>2 or (s->>'myCompleted')::int<>1 then raise exception 'additional assignment or preservation failed';end if;
 s:=public.cherry_halloween('next_mission');if jsonb_array_length(s->'myEntries')<>2 then raise exception 'repeat request made duplicate';end if;
 s:=public.cherry_halloween('submit',jsonb_build_object('entry',second_id,'title','test second','image','data:image/png;base64,AAAA'));
 if (s->>'myCompleted')::int<>2 then raise exception 'completion count failed';end if;
 s:=public.cherry_halloween('submit',jsonb_build_object('entry',first_id,'title','test first edited','image','data:image/png;base64,AAAA'));
 if s#>>'{mine,title}'<>'test first edited' or (s->>'myCompleted')::int<>2 then raise exception 'old entry edit or double count';end if;
 s:=public.cherry_halloween('withdraw',jsonb_build_object('entry',first_id));if (s->>'myCompleted')::int<>1 then raise exception 'withdraw count failed';end if;
 s:=public.cherry_halloween('submit',jsonb_build_object('entry',first_id,'title','test first restored','image','data:image/png;base64,AAAA'));
 if jsonb_array_length(s->'gallery')<>0 or jsonb_array_length(s->'missionScores')<>0 then raise exception 'collection privacy leak';end if;
end;$test$;
reset role;
update cherry_private.halloween_event set phase='guessing' where id=1;
set local role authenticated;
set local request.jwt.claim.sub='66666666-6666-4666-8666-666666666662';
do $test$ declare s jsonb; target text; blocked boolean:=false;begin
 s:=public.cherry_halloween('state');
 if exists(select 1 from jsonb_array_elements(s->'gallery') g where g?'author' or g?'missionId' or g?'mission') then raise exception 'anonymous gallery leaked answers';end if;
 target:=s#>>'{gallery,0,id}';
 begin perform public.cherry_halloween('submit',jsonb_build_object('entry',target,'title','attack','image','data:image/png;base64,AAAA'));exception when raise_exception then blocked:=true;end;
 if not blocked then raise exception 'closed submission allowed';end if;
 if s->'mine'<>'null'::jsonb or jsonb_array_length(s->'myEntries')<>0 then raise exception 'other member private entries exposed';end if;
end;$test$;
reset role;
update cherry_private.halloween_event set phase='revealed' where id=1;
set local role authenticated;
set local request.jwt.claim.sub='66666666-6666-4666-8666-666666666661';
do $test$ declare s jsonb;begin
 s:=public.cherry_halloween('state');
 if not exists(select 1 from jsonb_array_elements(s->'missionScores') score where score->>'member'='__multi_test' and (score->>'completed')::int=2) then raise exception 'completion leaderboard failed';end if;
 if (s->>'canNext')::boolean then raise exception 'extra mission open after close';end if;
end;$test$;
reset role;
rollback;
select 'PASS: extra missions, preserved history, repeat safety, edit/withdraw counts, privacy, closed phase and leaderboard' as verification;
