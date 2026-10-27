-- Harden wallets and provide an atomic in-platform creator purchase transaction.
drop policy if exists "create own wallet" on public.crimblox_wallets;
create or replace function public.crimblox_create_wallet_for_profile()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.crimblox_wallets(user_id,balance,currency) values(new.id,0,'CR') on conflict(user_id) do nothing;
 return new;
end; $$;
drop trigger if exists crimblox_profile_wallet on public.crimblox_profiles;
create trigger crimblox_profile_wallet after insert on public.crimblox_profiles for each row execute function public.crimblox_create_wallet_for_profile();
insert into public.crimblox_wallets(user_id,balance,currency) select id,0,'CR' from public.crimblox_profiles on conflict(user_id) do nothing;
revoke insert,update,delete on public.crimblox_wallets from anon,authenticated;
create or replace function public.crimblox_purchase_product(p_product_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare buyer uuid:=auth.uid(); product_row public.crimblox_creator_products%rowtype; buyer_balance bigint; seller_balance bigint; platform_fee bigint; ledger_id uuid; purchase_id uuid;
begin
 if buyer is null then raise exception 'Sign in required'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<8 or length(p_idempotency_key)>128 then raise exception 'Valid idempotency key required'; end if;
 if exists(select 1 from public.crimblox_economy_ledger where idempotency_key=p_idempotency_key) then
  select id into ledger_id from public.crimblox_economy_ledger where idempotency_key=p_idempotency_key;
  select id into purchase_id from public.crimblox_purchases where ledger_id=ledger_id limit 1;
  return jsonb_build_object('purchase_id',purchase_id,'ledger_id',ledger_id,'status','already_processed');
 end if;
 select * into product_row from public.crimblox_creator_products where id=p_product_id and is_published=true for update;
 if not found then raise exception 'Product not found or not published'; end if;
 if product_row.creator_id=buyer then raise exception 'Cannot purchase your own product'; end if;
 if exists(select 1 from public.crimblox_purchases where buyer_id=buyer and product_id=p_product_id) then raise exception 'Already purchased'; end if;
 insert into public.crimblox_wallets(user_id,balance) values(buyer,0) on conflict(user_id) do nothing;
 insert into public.crimblox_wallets(user_id,balance) values(product_row.creator_id,0) on conflict(user_id) do nothing;
 select balance into buyer_balance from public.crimblox_wallets where user_id=buyer for update;
 select balance into seller_balance from public.crimblox_wallets where user_id=product_row.creator_id for update;
 if buyer_balance<product_row.price then raise exception 'Insufficient CR balance'; end if;
 platform_fee:=floor(product_row.price*0.10);
 update public.crimblox_wallets set balance=balance-product_row.price,updated_at=now() where user_id=buyer;
 update public.crimblox_wallets set balance=balance+(product_row.price-platform_fee),updated_at=now() where user_id=product_row.creator_id;
 insert into public.crimblox_economy_ledger(actor_id,recipient_id,product_id,amount,transaction_type,status,idempotency_key,metadata)
 values(buyer,product_row.creator_id,product_row.id,product_row.price,'purchase','completed',p_idempotency_key,jsonb_build_object('platform_fee',platform_fee,'currency','CR')) returning id into ledger_id;
 insert into public.crimblox_purchases(buyer_id,product_id,ledger_id,price_paid) values(buyer,p_product_id,ledger_id,product_row.price) returning id into purchase_id;
 return jsonb_build_object('purchase_id',purchase_id,'ledger_id',ledger_id,'status','completed','price',product_row.price,'platform_fee',platform_fee);
end; $$;
revoke all on function public.crimblox_purchase_product(uuid,text) from public,anon;
grant execute on function public.crimblox_purchase_product(uuid,text) to authenticated;
