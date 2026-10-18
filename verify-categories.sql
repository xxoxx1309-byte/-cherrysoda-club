-- Isolated fixtures and all data changes are rolled back.
begin;
insert into auth.users(id,email,email_confirmed_at) values ('77777777-7777-4777-8777-777777777771','category-admin@example.invalid',now()),('77777777-7777-4777-8777-777777777772','category-member@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id,is_admin) values ('77777777-7777-4777-8777-777777777771','__category_admin',true),('77777777-7777-4777-8777-777777777772','__category_member',false);
update public.cherry_content set document=jsonb_set(jsonb_set(document,'{categories}',coalesce(document->'categories','[]'::jsonb)||'[{"id":"__category_test","name":"분류 테스트"}]'::jsonb),'{members}',document->'members'||'[{"id":"__category_admin","name":"test admin"},{"id":"__category_member","name":"test member"}]'::jsonb),revision=revision+1 where id=1;
set local role authenticated;
set local request.jwt.claim.sub='77777777-7777-4777-8777-777777777772';
insert into public.cherry_records(id,member_id,user_id,title,date,kind,category_id,images) values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','__category_member','77777777-7777-4777-8777-777777777772','category test',current_date,'free','__category_test','[]');
do $$declare denied boolean:=false;n bigint;d jsonb;v bigint;begin
 if not exists(select 1 from public.cherry_records where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and category_id='__category_test') then raise exception 'member selection failed';end if;
 begin update public.cherry_records set category_id='__not_registered' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';exception when check_violation then denied:=true;end;
 if not denied then raise exception 'invalid category accepted';end if;
 select document,revision into d,v from public.cherry_content where id=1;denied:=false;
 begin perform public.cherry_publish(d,v);exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'member can publish catalog';end if;
 update public.cherry_content set document=jsonb_set(document,'{categories}','[]') where id=1;get diagnostics n=row_count;
 if n<>0 then raise exception 'member can update catalog';end if;
end$$;
set local request.jwt.claim.sub='77777777-7777-4777-8777-777777777771';
do $$declare d jsonb;v bigint;next_v bigint;denied boolean:=false;begin
 select document,revision into d,v from public.cherry_content where id=1;
 d:=jsonb_set(d,'{records}',(d->'records')||coalesce((select jsonb_agg(jsonb_build_object('id',id,'memberId',member_id,'title',title,'date',date,'kind',kind,'themeId',coalesce(theme_id,''),'description',description,'musicUrl',music_url,'images',images,'tags',tags,'categoryId',coalesce(category_id,''),'_cloud',true)) from public.cherry_records where deleted_at is null),'[]'));
 next_v:=public.cherry_publish(d,v);
 if next_v<=v or not exists(select 1 from public.cherry_records where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and category_id='__category_test') then raise exception 'host publish lost category';end if;
 -- Older clients omit category fields: neither catalog nor selections may be erased.
 d:=d-'categories';d:=jsonb_set(d,'{records}',coalesce((select jsonb_agg(r-'categoryId') from jsonb_array_elements(d->'records') r),'[]'));
 next_v:=public.cherry_publish(d,next_v);
 if not exists(select 1 from public.cherry_content c cross join lateral jsonb_array_elements(c.document->'categories') item where item->>'id'='__category_test') or not exists(select 1 from public.cherry_records where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and category_id='__category_test') then raise exception 'old client erased categories';end if;
 begin update public.cherry_content set document=jsonb_set(document,'{categories}','[]') where id=1;exception when raise_exception then denied:=true;end;
 if not denied then raise exception 'used category deletion accepted';end if;
end$$;
reset role;
rollback;
select 'PASS: member category save, invalid categories denied, host-only catalog, publish and older clients preserve selections, used categories protected' as result;
