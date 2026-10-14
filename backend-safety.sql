begin;
drop trigger cherry_record_revision on public.cherry_records;
create trigger cherry_record_revision after insert or update or delete on public.cherry_records for each row execute function cherry_private.bump_revision();
create function cherry_private.valid_record_images(p jsonb) returns boolean
language sql immutable security invoker set search_path='' as $$
  select jsonb_typeof(p)='array' and not exists(
    select 1 from jsonb_array_elements_text(p) x where x is null or
    x !~ '^(assets/[a-zA-Z0-9._-]+|https://aqessidqzmekfigbglkc[.]supabase[.]co/storage/v1/object/public/cherry-images/[a-zA-Z0-9._/-]+)$'
  );
$$;
revoke all on function cherry_private.valid_record_images(jsonb) from public;
grant execute on function cherry_private.valid_record_images(jsonb) to authenticated;
alter table public.cherry_records add constraint cherry_valid_images check(cherry_private.valid_record_images(images));
alter table public.cherry_records add constraint cherry_title_nonblank check(length(trim(title))>0);
create function cherry_private.record_references(p_member text,p_theme text) returns boolean
language sql stable security invoker set search_path='' as $$
  select exists(select 1 from public.cherry_content c, jsonb_array_elements(c.document->'members') m where m->>'id'=p_member)
  and (p_theme is null or exists(select 1 from public.cherry_content c, jsonb_array_elements(c.document->'themes') t where t->>'id'=p_theme));
$$;
revoke all on function cherry_private.record_references(text,text) from public;
grant execute on function cherry_private.record_references(text,text) to authenticated;
alter table public.cherry_records add constraint cherry_valid_references check(cherry_private.record_references(member_id,theme_id));

create function cherry_private.trash_list() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
  return(select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'memberId',member_id,'date',date)),'[]'::jsonb) from public.cherry_records where deleted_at is not null);
end;$$;
create function cherry_private.restore_record(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not cherry_private.is_admin() then raise exception '관리자 권한이 필요합니다';end if;
  update public.cherry_records set deleted_at=null where id=p_id;
end;$$;
revoke all on function cherry_private.trash_list() from public;
revoke all on function cherry_private.restore_record(uuid) from public;
grant execute on function cherry_private.trash_list() to authenticated;
grant execute on function cherry_private.restore_record(uuid) to authenticated;
create function public.cherry_trash_list() returns jsonb language sql security invoker set search_path='' as $$select cherry_private.trash_list();$$;
create function public.cherry_restore_record(p_id uuid) returns void language sql security invoker set search_path='' as $$select cherry_private.restore_record(p_id);$$;
revoke all on function public.cherry_trash_list() from public;
revoke all on function public.cherry_restore_record(uuid) from public;
grant execute on function public.cherry_trash_list() to authenticated;
grant execute on function public.cherry_restore_record(uuid) to authenticated;
alter table public.cherry_records add constraint cherry_date_range check(date between date '0001-01-01' and date '9999-12-31');
commit;
