-- Keep private owner/admin visibility so UPDATE ... RETURNING supports soft deletion.
begin;
alter policy records_read on public.cherry_records to anon using(deleted_at is null);
create policy records_auth_read on public.cherry_records for select to authenticated using(
  deleted_at is null or (select cherry_private.is_admin()) or
  (user_id=(select auth.uid()) and member_id=(select cherry_private.current_member()))
);
commit;
