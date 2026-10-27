drop policy if exists "licensed marketplace asset downloads" on storage.objects;
create policy "licensed marketplace asset downloads" on storage.objects for select to authenticated using (
 bucket_id='crimblox-backend-objects' and exists (
  select 1 from public.crimblox_assets a
  join public.crimblox_creator_products p on p.asset_id=a.id
  where a.storage_path=name and p.is_published=true
  and (a.owner_id=auth.uid() or p.price=0 or exists(
    select 1 from public.crimblox_purchases pu where pu.product_id=p.id and pu.buyer_id=auth.uid()
  ))
 )
);
