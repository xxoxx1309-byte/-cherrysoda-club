begin;
alter table public.cherry_records add column if not exists category_id text;
do $$begin if not exists(select 1 from pg_constraint where conrelid='public.cherry_records'::regclass and conname='cherry_category_id_format') then alter table public.cherry_records add constraint cherry_category_id_format check(category_id is null or category_id ~ '^[a-zA-Z0-9_-]{1,100}$');end if;end$$;

-- Invoker checks use already-public category definitions; no new client privileges.
create or replace function cherry_private.check_record_category() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.category_id is not null and not exists(select 1 from public.cherry_content c cross join lateral jsonb_array_elements(coalesce(c.document->'categories','[]'::jsonb)) item where c.id=1 and item->>'id'=new.category_id) then
  raise exception '등록된 다꾸 카테고리를 선택해주세요' using errcode='23514';
 end if;
 return new;
end$$;
revoke all on function cherry_private.check_record_category() from public,anon,authenticated;
create or replace trigger cherry_category_record_check before insert or update of category_id on public.cherry_records for each row execute function cherry_private.check_record_category();

create or replace function cherry_private.check_category_catalog() returns trigger
language plpgsql security invoker set search_path='' as $$
declare cats jsonb:=coalesce(new.document->'categories','[]'::jsonb);
begin
 if jsonb_typeof(cats)<>'array' then raise exception '카테고리 목록을 확인해주세요';end if;
 if jsonb_array_length(cats)>50 or exists(select 1 from jsonb_array_elements(cats) c where jsonb_typeof(c)<>'object' or coalesce(c->>'id','')!~'^[a-zA-Z0-9_-]{1,100}$' or jsonb_typeof(c->'name') is distinct from 'string' or length(trim(c->>'name')) not between 1 and 40) then raise exception '카테고리는 최대 50개이며 이름은 1~40자로 입력해주세요';end if;
 if (select count(*) from jsonb_array_elements(cats))<>(select count(distinct c->>'id') from jsonb_array_elements(cats) c) or (select count(*) from jsonb_array_elements(cats))<>(select count(distinct lower(trim(c->>'name'))) from jsonb_array_elements(cats) c) then raise exception '카테고리 ID 또는 이름이 중복됩니다';end if;
 if exists(select 1 from public.cherry_records r where r.category_id is not null and not exists(select 1 from jsonb_array_elements(cats) c where c->>'id'=r.category_id)) then raise exception '사용 중인 카테고리는 삭제할 수 없어요. 휴지통을 포함한 기록의 분류를 먼저 변경·저장해주세요';end if;
 if exists(select 1 from jsonb_array_elements(new.document->'records') r where coalesce(r->>'categoryId','')<>'' and not exists(select 1 from jsonb_array_elements(cats) c where c->>'id'=r->>'categoryId')) then raise exception '기록에 연결된 카테고리를 확인해주세요';end if;
 return new;
end$$;
revoke all on function cherry_private.check_category_catalog() from public,anon,authenticated;
create or replace trigger cherry_category_catalog_check before insert or update of document on public.cherry_content for each row execute function cherry_private.check_category_catalog();

-- Retain host checks, revision locking, BGM, photos, and soft deletion behavior.
create or replace function cherry_private.publish_content(p_document jsonb,p_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare current_revision bigint; r jsonb;
begin
 if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
 select revision into current_revision from public.cherry_content where id=1 for update;
 if current_revision is distinct from p_revision then raise exception '내용이 변경됐습니다. 초안을 백업한 뒤 최신 내용을 불러와주세요';end if;
 if p_document->>'version'<>'1' or jsonb_typeof(p_document->'members')<>'array' or jsonb_typeof(p_document->'records')<>'array' then raise exception '내용 형식을 확인해주세요';end if;
 -- Older clients omit categories; preserve the published catalog.
 if not(p_document?'categories') then p_document:=jsonb_set(p_document,'{categories}',coalesce((select document->'categories' from public.cherry_content where id=1),'[]'::jsonb));end if;
 update public.cherry_content set document=jsonb_set(p_document,'{records}',coalesce((select jsonb_agg(value) from jsonb_array_elements(p_document->'records') where coalesce(value->>'_cloud','false')<>'true'),'[]'::jsonb)),revision=revision+1 where id=1;
 for r in select value from jsonb_array_elements(p_document->'records') where value->>'_cloud'='true' loop
  update public.cherry_records set title=r->>'title',member_id=r->>'memberId',date=(r->>'date')::date,kind=r->>'kind',theme_id=nullif(r->>'themeId',''),description=coalesce(r->>'description',''),music_url=case when r?'musicUrl' then coalesce(r->>'musicUrl','') else music_url end,category_id=case when r?'categoryId' then nullif(r->>'categoryId','') else category_id end,images=r->'images',tags=r->'tags' where id=(r->>'id')::uuid and deleted_at is null;
 end loop;
 update public.cherry_records set deleted_at=now() where deleted_at is null and not exists(select 1 from jsonb_array_elements(p_document->'records') item where item->>'_cloud'='true' and item->>'id'=cherry_records.id::text);
 select revision into current_revision from public.cherry_content where id=1;
 return current_revision;
end$$;
revoke all on function cherry_private.publish_content(jsonb,bigint) from public,anon;
grant execute on function cherry_private.publish_content(jsonb,bigint) to authenticated;
grant select(category_id) on public.cherry_records to anon,authenticated;
notify pgrst,'reload schema';
commit;
