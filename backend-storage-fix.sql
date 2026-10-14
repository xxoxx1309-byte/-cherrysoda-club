begin;
-- Public image URLs remain readable; anonymous visitors cannot enumerate the bucket.
alter policy cherry_images_read on storage.objects to authenticated using(
  bucket_id='cherry-images' and ((select cherry_private.is_admin()) or (
    (storage.foldername(name))[1]=(select auth.uid())::text
    and (select cherry_private.current_member()) is not null
  ))
);

revoke select on public.cherry_records from anon,authenticated;
grant select(id,member_id,title,date,kind,theme_id,description,images,tags,created_at,deleted_at) on public.cherry_records to anon,authenticated;
commit;
