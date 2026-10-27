create or replace function public.crimblox_purchase_product(p_product_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_buyer uuid:=auth.uid();
 v_product public.crimblox_creator_products%rowtype;
 v_buyer_balance bigint;
 v_platform_fee bigint;
 v_ledger_id uuid;
 v_purchase_id uuid;
begin
 if v_buyer is null then raise exception 'Sign in required'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<8 or length(p_idempotency_key)>128 then raise exception 'Valid idempotency key required'; end if;
 select id into v_ledger_id from public.crimblox_economy_ledger where idempotency_key=p_idempotency_key;
 if v_ledger_id is not null then
  select id into v_purchase_id from public.crimblox_purchases p where p.ledger_id=v_ledger_id limit 1;
  return jsonb_build_object('purchase_id',v_purchase_id,'ledger_id',v_ledger_id,'status','already_processed');
 end if;
 select * into v_product from public.crimblox_creator_products p where p.id=p_product_id and p.is_published=true for update;
 if not found then raise exception 'Product not found or not published'; end if;
 if v_product.creator_id=v_buyer then raise exception 'Cannot purchase your own product'; end if;
 if exists(select 1 from public.crimblox_purchases p where p.buyer_id=v_buyer and p.product_id=p_product_id) then raise exception 'Already purchased'; end if;
 insert into public.crimblox_wallets(user_id,balance) values(v_buyer,0) on conflict(user_id) do nothing;
 insert into public.crimblox_wallets(user_id,balance) values(v_product.creator_id,0) on conflict(user_id) do nothing;
 select w.balance into v_buyer_balance from public.crimblox_wallets w where w.user_id=v_buyer for update;
 if v_buyer_balance<v_product.price then raise exception 'Insufficient CR balance'; end if;
 v_platform_fee:=floor(v_product.price*0.10);
 update public.crimblox_wallets set balance=balance-v_product.price,updated_at=now() where user_id=v_buyer;
 update public.crimblox_wallets set balance=balance+(v_product.price-v_platform_fee),updated_at=now() where user_id=v_product.creator_id;
 if v_product.price>0 then
  insert into public.crimblox_economy_ledger(actor_id,recipient_id,product_id,amount,transaction_type,status,idempotency_key,metadata)
  values(v_buyer,v_product.creator_id,v_product.id,v_product.price,'purchase','completed',p_idempotency_key,jsonb_build_object('platform_fee',v_platform_fee,'currency','CR')) returning id into v_ledger_id;
 end if;
 insert into public.crimblox_purchases(buyer_id,product_id,ledger_id,price_paid) values(v_buyer,p_product_id,v_ledger_id,v_product.price) returning id into v_purchase_id;
 return jsonb_build_object('purchase_id',v_purchase_id,'ledger_id',v_ledger_id,'status','completed','price',v_product.price,'platform_fee',v_platform_fee);
end; $$;
revoke all on function public.crimblox_purchase_product(uuid,text) from public,anon;
grant execute on function public.crimblox_purchase_product(uuid,text) to authenticated;
