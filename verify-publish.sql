begin;
insert into auth.users(id,email,email_confirmed_at) values
('55555555-5555-4555-8555-555555555555','cherry-publish@example.invalid',now());
insert into cherry_private.memberships(user_id,member_id,is_admin) values
('55555555-5555-4555-8555-555555555555','publish_test_admin',true);
insert into public.cherry_records(id,member_id,user_id,title,date,kind) values
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','yuki','55555555-5555-4555-8555-555555555555','original',current_date,'free');
set local role authenticated;
set local request.jwt.claim.sub='55555555-5555-4555-8555-555555555555';
do $$declare d jsonb;v bigint;new_v bigint;begin
  select document,revision into d,v from public.cherry_content where id=1;
  d=jsonb_set(d,'{themes}',d->'themes'||jsonb_build_array(jsonb_build_object('id','test_new_theme','title','test','start','2026-10-19','end','2026-10-25')));
  d=jsonb_set(d,'{records}',d->'records'||coalesce((select jsonb_agg(jsonb_build_object('id',id,'memberId',member_id,'title','edited','date',date,'kind',kind,'themeId','test_new_theme','description',description,'images',images,'tags',tags,'_cloud',true)) from public.cherry_records where deleted_at is null),'[]'::jsonb));
  new_v=public.cherry_publish(d,v);
  if not exists(select 1 from public.cherry_records where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and title='edited' and theme_id='test_new_theme') then raise exception 'atomic publish failed';end if;
  if new_v<=v then raise exception 'revision did not advance';end if;
  begin perform public.cherry_publish(d,v);raise exception 'stale revision accepted';
  exception when raise_exception then if sqlerrm='stale revision accepted' then raise;end if;end;
end;$$;
reset role;
select 'atomic publish and stale revision checks passed' as result;
rollback;
