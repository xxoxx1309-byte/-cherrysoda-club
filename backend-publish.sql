-- Atomic owner publishing; record edits invalidate stale owner drafts.
begin;
create function cherry_private.bump_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update public.cherry_content set revision=revision+1 where id=1;
  return null;
end; $$;
revoke all on function cherry_private.bump_revision() from public;
create trigger cherry_record_revision after insert or update or delete on public.cherry_records
for each row execute function cherry_private.bump_revision();

create function cherry_private.publish_content(p_document jsonb,p_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare current_revision bigint; r jsonb;
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다'; end if;
  select revision into current_revision from public.cherry_content where id=1 for update;
  if current_revision is distinct from p_revision then raise exception '내용이 변경됐습니다. 초안을 백업한 뒤 최신 내용을 불러와주세요'; end if;
  if p_document->>'version'<>'1' or jsonb_typeof(p_document->'members')<>'array' or jsonb_typeof(p_document->'records')<>'array' then raise exception '내용 형식을 확인해주세요'; end if;
  update public.cherry_content set document=jsonb_set(p_document,'{records}',coalesce((select jsonb_agg(value) from jsonb_array_elements(p_document->'records') where coalesce(value->>'_cloud','false')<>'true'),'[]'::jsonb)),revision=revision+1 where id=1;
  for r in select value from jsonb_array_elements(p_document->'records') where value->>'_cloud'='true' loop
    update public.cherry_records set title=r->>'title', member_id=r->>'memberId',date=(r->>'date')::date,
      kind=r->>'kind',theme_id=nullif(r->>'themeId',''),description=coalesce(r->>'description',''),images=r->'images',tags=r->'tags'
    where id=(r->>'id')::uuid and deleted_at is null;
  end loop;
  update public.cherry_records set deleted_at=now()
  where deleted_at is null and not exists (
    select 1 from jsonb_array_elements(p_document->'records') item where item->>'_cloud'='true' and item->>'id'=cherry_records.id::text
  );
  select revision into current_revision from public.cherry_content where id=1;
  return current_revision;
end; $$;
revoke all on function cherry_private.publish_content(jsonb,bigint) from public;
grant execute on function cherry_private.publish_content(jsonb,bigint) to authenticated;
create function public.cherry_publish(p_document jsonb,p_revision bigint) returns bigint
language sql security invoker set search_path='' as $$ select cherry_private.publish_content(p_document,p_revision); $$;
revoke all on function public.cherry_publish(jsonb,bigint) from public;
grant execute on function public.cherry_publish(jsonb,bigint) to authenticated;
commit;
