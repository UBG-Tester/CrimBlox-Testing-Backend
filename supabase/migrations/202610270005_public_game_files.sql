drop policy if exists "public published experience files" on storage.objects;
create policy "public published experience files" on storage.objects for select to authenticated using (
 bucket_id='crimblox-backend-objects' and exists (
  select 1 from public.crimblox_experience_versions v
  join public.crimblox_experiences e on e.id=v.experience_id
  where v.file_path=name and e.visibility='public'
 )
);
-- Wallet balance is only modified by trusted purchase RPC or server-side service-role operations.
revoke update on public.crimblox_wallets from anon,authenticated;
