-- Apply after backend-halloween.sql. Preserves existing missions, entries and guesses.
begin;
alter table cherry_private.halloween_entries add column if not exists mission_round integer not null default 1 check(mission_round>0);
alter table cherry_private.halloween_entries drop constraint if exists halloween_entries_member_id_key;
create unique index if not exists halloween_member_round on cherry_private.halloween_entries(member_id,mission_round);
create or replace function cherry_private.halloween_action(p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 me text; admin boolean; stage text; assignment integer; target uuid; own cherry_private.halloween_entries;
 gallery jsonb; ballots jsonb; results jsonb; owners jsonb; my_entry jsonb;
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다'; end if;
 me:=cherry_private.current_member(); admin:=cherry_private.is_admin();
 if me is null then raise exception '등록된 멤버만 참여할 수 있습니다'; end if;
 select phase into stage from cherry_private.halloween_event where id=1 for update;
 if stage is null then raise exception '이벤트 설정이 필요합니다'; end if;
 if p_action='configure_missions' then
   if not admin then raise exception '방장만 미션을 설정할 수 있습니다'; end if;
   if stage<>'collecting' or exists(select 1 from cherry_private.halloween_entries) then raise exception '미션 배정 전까지만 목록을 변경할 수 있습니다'; end if;
   if jsonb_typeof(p_payload->'missions') is distinct from 'array' then raise exception '미션 목록을 입력해주세요'; end if;
   if jsonb_array_length(p_payload->'missions') not between 1 and 50 then raise exception '미션은 1~50개로 입력해주세요'; end if;
   if exists(select 1 from jsonb_array_elements(p_payload->'missions') m where jsonb_typeof(m)<>'string' or length(trim(m#>>'{}')) not between 1 and 200)
     then raise exception '미션 한 개는 1~200자로 입력해주세요'; end if;
   if (select count(distinct trim(m#>>'{}')) from jsonb_array_elements(p_payload->'missions') m)<>jsonb_array_length(p_payload->'missions')
     then raise exception '중복된 미션을 확인해주세요'; end if;
   delete from cherry_private.halloween_missions;
   insert into cherry_private.halloween_missions(id,label)
     select n::integer,trim(m#>>'{}') from jsonb_array_elements(p_payload->'missions') with ordinality as x(m,n);
 elsif p_action='append_missions' then
   if not admin then raise exception '방장만 미션을 추가할 수 있습니다'; end if;
   if stage<>'collecting' then raise exception '접수 중에만 미션을 추가할 수 있습니다'; end if;
   if jsonb_typeof(p_payload->'missions') is distinct from 'array' then raise exception '추가할 미션을 입력해주세요'; end if;
   if jsonb_array_length(p_payload->'missions')<1 or jsonb_array_length(p_payload->'missions')+(select count(*) from cherry_private.halloween_missions)>50 then raise exception '전체 미션은 최대 50개입니다'; end if;
   if exists(select 1 from jsonb_array_elements(p_payload->'missions') m where jsonb_typeof(m)<>'string' or length(trim(m#>>'{}')) not between 1 and 200) then raise exception '미션 한 개는 1~200자로 입력해주세요'; end if;
   if (select count(distinct trim(m#>>'{}')) from jsonb_array_elements(p_payload->'missions') m)<>jsonb_array_length(p_payload->'missions') or exists(select 1 from jsonb_array_elements(p_payload->'missions') m join cherry_private.halloween_missions h on h.label=trim(m#>>'{}')) then raise exception '이미 등록했거나 중복된 미션입니다'; end if;
   insert into cherry_private.halloween_missions(id,label) select (select coalesce(max(id),0) from cherry_private.halloween_missions)+n::integer,trim(m#>>'{}') from jsonb_array_elements(p_payload->'missions') with ordinality as x(m,n);
 elsif p_action in ('join','next_mission') then
   if stage<>'collecting' then raise exception '참여 접수가 마감됐어요'; end if;
   if p_action='next_mission' and not exists(select 1 from cherry_private.halloween_entries where member_id=me and submitted) then raise exception '현재 미션의 작품을 먼저 제출해주세요'; end if;
   if not exists(select 1 from cherry_private.halloween_entries where member_id=me and not submitted)
     and (p_action='next_mission' or not exists(select 1 from cherry_private.halloween_entries where member_id=me)) then
     select m.id into assignment from cherry_private.halloween_missions m where not exists(select 1 from cherry_private.halloween_entries e where e.mission_id=m.id) order by random() limit 1;
     if assignment is null then raise exception '배정할 미션이 남아 있지 않아요. 방장에게 추가 등록을 요청해주세요'; end if;
     insert into cherry_private.halloween_entries(member_id,mission_id,mission_round) select me,assignment,coalesce(max(mission_round),0)+1 from cherry_private.halloween_entries where member_id=me;
   end if;
 elsif p_action='submit' then
   if stage<>'collecting' then raise exception '제출과 수정이 마감됐어요'; end if;
   if length(trim(coalesce(p_payload->>'title',''))) not between 1 and 100
     or length(coalesce(p_payload->>'image','')) not between 1 and 2000000
     or coalesce(p_payload->>'image','') !~ '^data:image/(webp|jpeg|png);base64,[A-Za-z0-9+/=]+$'
     then raise exception '제목과 사진을 확인해주세요'; end if;
   select id into target from cherry_private.halloween_entries where member_id=me and (nullif(p_payload->>'entry','') is null or id=(p_payload->>'entry')::uuid) order by submitted,mission_round desc limit 1;
   if target is null then raise exception '본인에게 배정된 미션을 선택해주세요'; end if;
   update cherry_private.halloween_entries set title=trim(p_payload->>'title'),image=p_payload->>'image',submitted=true where id=target and member_id=me;
   if not found then raise exception '먼저 비밀 미션을 받아주세요'; end if;
 elsif p_action='withdraw' then
   if stage<>'collecting' then raise exception '제출 취소가 마감됐어요'; end if;
   select id into target from cherry_private.halloween_entries where member_id=me and (nullif(p_payload->>'entry','') is null or id=(p_payload->>'entry')::uuid) order by submitted,mission_round desc limit 1;
   if target is null then raise exception '본인의 미션을 선택해주세요'; end if;
   if exists(select 1 from cherry_private.halloween_entries where member_id=me and id<>target and not submitted) then raise exception '진행 중인 다른 미션을 먼저 제출해주세요'; end if;
   update cherry_private.halloween_entries set title='',image='',submitted=false where id=target and member_id=me;
   -- Retain the assignment to prevent mission rerolls.
 elsif p_action='guess' then
   if stage<>'guessing' then raise exception '현재 추리 접수 시간이 아닙니다'; end if;
   target:=(p_payload->>'entry')::uuid;
   if not exists(select 1 from cherry_private.halloween_entries where id=target and submitted and member_id<>me)
     then raise exception '다른 멤버의 공개 작품을 선택해주세요'; end if;
   if not exists(select 1 from public.cherry_content c,jsonb_array_elements(c.document->'members') m where m->>'id'=p_payload->>'author')
     then raise exception '멤버를 선택해주세요'; end if;
   insert into cherry_private.halloween_guesses(voter,entry_id,author_guess,mission_guess)
     values(me,target,p_payload->>'author',(p_payload->>'mission')::integer)
     on conflict(voter,entry_id) do update set author_guess=excluded.author_guess,mission_guess=excluded.mission_guess;
 elsif p_action='phase' then
   if not admin then raise exception '방장만 진행 단계를 변경할 수 있습니다'; end if;
   if not ((stage='collecting' and p_payload->>'phase'='guessing') or (stage='guessing' and p_payload->>'phase'='revealed'))
     then raise exception '접수 → 추리 → 정체 공개 순서로 진행합니다'; end if;
   if not exists(select 1 from cherry_private.halloween_entries where submitted) then raise exception '제출된 작품이 없습니다'; end if;
   update cherry_private.halloween_event set phase=p_payload->>'phase' where id=1 returning phase into stage;
 elsif p_action<>'state' then raise exception '지원하지 않는 요청입니다';
 end if;
 select * into own from cherry_private.halloween_entries where member_id=me order by
   case when p_action in ('state','submit','withdraw') and id::text=p_payload->>'entry' then 0 else 1 end,submitted,mission_round desc limit 1;
 if own.id is not null then
   select jsonb_build_object('id',own.id,'round',own.mission_round,'mission',m.label,'missionId',own.mission_id,'title',own.title,'image',own.image,'submitted',own.submitted)
   into my_entry from cherry_private.halloween_missions m where m.id=own.mission_id;
 end if;
 -- Never return account IDs, author identities, mission assignments or submission times before reveal.
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'alias','유령 '||upper(left(e.id::text,6)),
   'title',e.title,'image',e.image,'mine',e.member_id=me)
   ||case when stage='revealed' then jsonb_build_object('author',e.member_id,'mission',m.label,'missionId',m.id) else '{}'::jsonb end
   order by e.id),'[]'::jsonb)
 into gallery from cherry_private.halloween_entries e join cherry_private.halloween_missions m on m.id=e.mission_id
 where e.submitted and stage in ('guessing','revealed');
 select coalesce(jsonb_agg(jsonb_build_object('entry',entry_id,'author',author_guess,'mission',mission_guess)),'[]'::jsonb)
 into ballots from cherry_private.halloween_guesses where voter=me;
 results:='[]'::jsonb;
 if stage='revealed' then
   select coalesce(jsonb_agg(to_jsonb(s) order by s.score desc,s.member),'[]'::jsonb) into results from (
     select h.member_id as member,coalesce(sum((g.author_guess=e.member_id)::integer+(g.mission_guess=e.mission_id)::integer),0)::integer as score
     from cherry_private.memberships h left join cherry_private.halloween_guesses g on g.voter=h.member_id
     left join cherry_private.halloween_entries e on e.id=g.entry_id and e.submitted
     where h.active and not h.is_admin and exists(select 1 from cherry_private.halloween_guesses v where v.voter=h.member_id)
     group by h.member_id
   ) s;
 end if;
 owners:='[]'::jsonb;
 if admin then
   select coalesce(jsonb_agg(jsonb_build_object('member',e.member_id,'round',e.mission_round,'mission',m.label,'submitted',e.submitted) order by e.member_id,e.mission_round),'[]'::jsonb)
     into owners from cherry_private.halloween_entries e join cherry_private.halloween_missions m on m.id=e.mission_id;
 end if;
 return jsonb_build_object('phase',stage,'mine',my_entry,'gallery',gallery,'guesses',ballots,'scores',results,'adminEntries',owners,
   'missionCount',(select count(*) from cherry_private.halloween_missions),'adminMissions',case when admin then (select coalesce(jsonb_agg(label order by id),'[]'::jsonb) from cherry_private.halloween_missions) else '[]'::jsonb end,
   'version',2,
   'myEntries',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'round',mission_round,'title',title,'submitted',submitted) order by mission_round),'[]'::jsonb) from cherry_private.halloween_entries where member_id=me),
   'myCompleted',(select count(*) from cherry_private.halloween_entries where member_id=me and submitted),
   'canNext',stage='collecting' and exists(select 1 from cherry_private.halloween_entries where member_id=me and submitted) and not exists(select 1 from cherry_private.halloween_entries where member_id=me and not submitted) and exists(select 1 from cherry_private.halloween_missions m where not exists(select 1 from cherry_private.halloween_entries e where e.mission_id=m.id)),
   'remaining',(select count(*) from cherry_private.halloween_missions m where not exists(select 1 from cherry_private.halloween_entries e where e.mission_id=m.id)),
   'missionScores',case when stage='revealed' or admin then (select coalesce(jsonb_agg(to_jsonb(s) order by s.completed desc,s.member),'[]'::jsonb) from (select h.member_id as member,count(e.id)::integer as completed from cherry_private.memberships h join cherry_private.halloween_entries e on e.member_id=h.member_id and e.submitted where h.active and not h.is_admin group by h.member_id) s) else '[]'::jsonb end,
   'joined',(select count(distinct member_id) from cherry_private.halloween_entries),'submitted',(select count(*) from cherry_private.halloween_entries where submitted),
   'missions',case when stage in ('guessing','revealed') then (select jsonb_agg(jsonb_build_object('id',id,'label',label) order by id) from cherry_private.halloween_missions) else '[]'::jsonb end);
end;$$;
revoke all on function cherry_private.halloween_action(text,jsonb) from public,anon,authenticated;
grant execute on function cherry_private.halloween_action(text,jsonb) to authenticated;
create or replace function public.cherry_halloween(p_action text default 'state',p_payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select cherry_private.halloween_action(p_action,p_payload); $$;
revoke all on function public.cherry_halloween(text,jsonb) from public,anon,authenticated;
grant execute on function public.cherry_halloween(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
