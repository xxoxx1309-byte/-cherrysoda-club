alter table public.cherry_records add column music_url text not null default '';
alter table public.cherry_records add constraint cherry_records_music_url_check check (music_url='' or (length(music_url)<=2048 and music_url ~ '^https://(www\.youtube\.com|youtube\.com|m\.youtube\.com|music\.youtube\.com|youtu\.be|open\.spotify\.com|spotify\.link)/[^[:space:]]+$'));
grant select (music_url) on public.cherry_records to anon,authenticated;
CREATE OR REPLACE FUNCTION cherry_private.publish_content(p_document jsonb, p_revision bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare current_revision bigint; r jsonb;
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다'; end if;
  select revision into current_revision from public.cherry_content where id=1 for update;
  if current_revision is distinct from p_revision then raise exception '내용이 변경됐습니다. 초안을 백업한 뒤 최신 내용을 불러와주세요'; end if;
  if p_document->>'version'<>'1' or jsonb_typeof(p_document->'members')<>'array' or jsonb_typeof(p_document->'records')<>'array' then raise exception '내용 형식을 확인해주세요'; end if;
  update public.cherry_content set document=jsonb_set(p_document,'{records}',coalesce((select jsonb_agg(value) from jsonb_array_elements(p_document->'records') where coalesce(value->>'_cloud','false')<>'true'),'[]'::jsonb)),revision=revision+1 where id=1;
  for r in select value from jsonb_array_elements(p_document->'records') where value->>'_cloud'='true' loop
    update public.cherry_records set title=r->>'title', member_id=r->>'memberId',date=(r->>'date')::date,
      kind=r->>'kind',theme_id=nullif(r->>'themeId',''),description=coalesce(r->>'description',''),music_url=case when r ? 'musicUrl' then coalesce(r->>'musicUrl','') else music_url end,images=r->'images',tags=r->'tags'
    where id=(r->>'id')::uuid and deleted_at is null;
  end loop;
  update public.cherry_records set deleted_at=now()
  where deleted_at is null and not exists (
    select 1 from jsonb_array_elements(p_document->'records') item where item->>'_cloud'='true' and item->>'id'=cherry_records.id::text
  );
  select revision into current_revision from public.cherry_content where id=1;
  return current_revision;
end; $function$
