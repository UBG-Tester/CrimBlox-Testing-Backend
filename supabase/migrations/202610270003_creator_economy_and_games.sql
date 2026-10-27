-- CrimBlox creator economy and game publishing foundation
create table if not exists public.crimblox_experiences (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 title text not null check(char_length(title) between 3 and 100),
 description text not null default '',
 genre text not null default 'Other',
 visibility text not null default 'private' check(visibility in ('private','unlisted','public')),
 thumbnail_path text,
 active_version_id uuid,
 visits bigint not null default 0 check(visits >= 0),
 likes_count bigint not null default 0 check(likes_count >= 0),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.crimblox_experience_versions (
 id uuid primary key default gen_random_uuid(),
 experience_id uuid not null references public.crimblox_experiences(id) on delete cascade,
 owner_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 version_number integer not null check(version_number > 0),
 file_path text not null,
 file_name text not null,
 file_size bigint not null default 0,
 changelog text not null default '',
 created_at timestamptz not null default now(),
 unique(experience_id,version_number)
);
do $$ begin
 if not exists(select 1 from pg_constraint where conname='crimblox_experiences_active_version_fk') then
  alter table public.crimblox_experiences add constraint crimblox_experiences_active_version_fk foreign key(active_version_id) references public.crimblox_experience_versions(id) on delete set null;
 end if;
end $$;
create table if not exists public.crimblox_experience_votes (
 experience_id uuid not null references public.crimblox_experiences(id) on delete cascade,
 user_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 vote smallint not null check(vote in (-1,1)),
 created_at timestamptz not null default now(),
 primary key(experience_id,user_id)
);
create table if not exists public.crimblox_asset_votes (
 asset_id uuid not null references public.crimblox_assets(id) on delete cascade,
 user_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 vote smallint not null check(vote in (-1,1)),
 created_at timestamptz not null default now(),
 primary key(asset_id,user_id)
);
create table if not exists public.crimblox_asset_comments (
 id uuid primary key default gen_random_uuid(),
 asset_id uuid not null references public.crimblox_assets(id) on delete cascade,
 author_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 3000),
 created_at timestamptz not null default now()
);
create table if not exists public.crimblox_follows (
 follower_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 creator_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,creator_id),
 check(follower_id <> creator_id)
);
create table if not exists public.crimblox_wallets (
 user_id uuid primary key references public.crimblox_profiles(id) on delete cascade,
 currency text not null default 'CR' check(currency='CR'),
 balance bigint not null default 0 check(balance >= 0),
 updated_at timestamptz not null default now()
);
create table if not exists public.crimblox_creator_products (
 id uuid primary key default gen_random_uuid(),
 creator_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 asset_id uuid references public.crimblox_assets(id) on delete set null,
 title text not null check(char_length(title) between 3 and 120),
 description text not null default '',
 price bigint not null default 0 check(price >= 0),
 product_type text not null default 'asset' check(product_type in ('asset','plugin','accessory','gamepass','private_server')),
 is_published boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.crimblox_economy_ledger (
 id uuid primary key default gen_random_uuid(),
 actor_id uuid not null references public.crimblox_profiles(id) on delete restrict,
 recipient_id uuid references public.crimblox_profiles(id) on delete restrict,
 product_id uuid references public.crimblox_creator_products(id) on delete set null,
 amount bigint not null check(amount > 0),
 transaction_type text not null check(transaction_type in ('purchase','creator_payout','refund','grant')),
 status text not null default 'pending' check(status in ('pending','completed','failed','refunded')),
 idempotency_key text unique,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create table if not exists public.crimblox_purchases (
 id uuid primary key default gen_random_uuid(),
 buyer_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 product_id uuid not null references public.crimblox_creator_products(id) on delete restrict,
 ledger_id uuid unique references public.crimblox_economy_ledger(id) on delete restrict,
 price_paid bigint not null check(price_paid >= 0),
 created_at timestamptz not null default now(),
 unique(buyer_id,product_id)
);
create table if not exists public.crimblox_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 kind text not null,
 title text not null,
 body text not null default '',
 target_url text,
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.crimblox_game_sessions (
 id uuid primary key default gen_random_uuid(),
 experience_id uuid not null references public.crimblox_experiences(id) on delete cascade,
 host_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 room_code text unique not null,
 status text not null default 'open' check(status in ('open','running','closed')),
 max_players integer not null default 20 check(max_players between 1 and 100),
 created_at timestamptz not null default now(),
 closed_at timestamptz
);
create table if not exists public.crimblox_game_session_members (
 session_id uuid not null references public.crimblox_game_sessions(id) on delete cascade,
 user_id uuid not null references public.crimblox_profiles(id) on delete cascade,
 joined_at timestamptz not null default now(),
 last_seen_at timestamptz not null default now(),
 primary key(session_id,user_id)
);

alter table public.crimblox_experiences enable row level security;
alter table public.crimblox_experience_versions enable row level security;
alter table public.crimblox_experience_votes enable row level security;
alter table public.crimblox_asset_votes enable row level security;
alter table public.crimblox_asset_comments enable row level security;
alter table public.crimblox_follows enable row level security;
alter table public.crimblox_wallets enable row level security;
alter table public.crimblox_creator_products enable row level security;
alter table public.crimblox_economy_ledger enable row level security;
alter table public.crimblox_purchases enable row level security;
alter table public.crimblox_notifications enable row level security;
alter table public.crimblox_game_sessions enable row level security;
alter table public.crimblox_game_session_members enable row level security;

drop policy if exists "public experiences visible" on public.crimblox_experiences;
create policy "public experiences visible" on public.crimblox_experiences for select to authenticated using(visibility='public' or owner_id=auth.uid());
drop policy if exists "owners create experiences" on public.crimblox_experiences;
create policy "owners create experiences" on public.crimblox_experiences for insert to authenticated with check(owner_id=auth.uid());
drop policy if exists "owners update experiences" on public.crimblox_experiences;
create policy "owners update experiences" on public.crimblox_experiences for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists "owners delete experiences" on public.crimblox_experiences;
create policy "owners delete experiences" on public.crimblox_experiences for delete to authenticated using(owner_id=auth.uid());

drop policy if exists "visible experience versions" on public.crimblox_experience_versions;
create policy "visible experience versions" on public.crimblox_experience_versions for select to authenticated using(owner_id=auth.uid() or exists(select 1 from public.crimblox_experiences e where e.id=experience_id and e.visibility='public'));
drop policy if exists "owners add versions" on public.crimblox_experience_versions;
create policy "owners add versions" on public.crimblox_experience_versions for insert to authenticated with check(owner_id=auth.uid() and exists(select 1 from public.crimblox_experiences e where e.id=experience_id and e.owner_id=auth.uid()));
drop policy if exists "owners remove versions" on public.crimblox_experience_versions;
create policy "owners remove versions" on public.crimblox_experience_versions for delete to authenticated using(owner_id=auth.uid());

drop policy if exists "read experience votes" on public.crimblox_experience_votes;
create policy "read experience votes" on public.crimblox_experience_votes for select to authenticated using(true);
drop policy if exists "set own experience votes" on public.crimblox_experience_votes;
create policy "set own experience votes" on public.crimblox_experience_votes for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "read asset votes" on public.crimblox_asset_votes;
create policy "read asset votes" on public.crimblox_asset_votes for select to authenticated using(true);
drop policy if exists "set own asset votes" on public.crimblox_asset_votes;
create policy "set own asset votes" on public.crimblox_asset_votes for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

drop policy if exists "read asset comments" on public.crimblox_asset_comments;
create policy "read asset comments" on public.crimblox_asset_comments for select to authenticated using(true);
drop policy if exists "write own asset comments" on public.crimblox_asset_comments;
create policy "write own asset comments" on public.crimblox_asset_comments for insert to authenticated with check(author_id=auth.uid());
drop policy if exists "delete own asset comments" on public.crimblox_asset_comments;
create policy "delete own asset comments" on public.crimblox_asset_comments for delete to authenticated using(author_id=auth.uid());

drop policy if exists "read follows" on public.crimblox_follows;
create policy "read follows" on public.crimblox_follows for select to authenticated using(true);
drop policy if exists "manage own follows" on public.crimblox_follows;
create policy "manage own follows" on public.crimblox_follows for all to authenticated using(follower_id=auth.uid()) with check(follower_id=auth.uid());

drop policy if exists "read own wallet" on public.crimblox_wallets;
create policy "read own wallet" on public.crimblox_wallets for select to authenticated using(user_id=auth.uid());
drop policy if exists "create own wallet" on public.crimblox_wallets;
create policy "create own wallet" on public.crimblox_wallets for insert to authenticated with check(user_id=auth.uid());

drop policy if exists "public products visible" on public.crimblox_creator_products;
create policy "public products visible" on public.crimblox_creator_products for select to authenticated using(is_published or creator_id=auth.uid());
drop policy if exists "creators manage products" on public.crimblox_creator_products;
create policy "creators manage products" on public.crimblox_creator_products for all to authenticated using(creator_id=auth.uid()) with check(creator_id=auth.uid());

drop policy if exists "read own ledger" on public.crimblox_economy_ledger;
create policy "read own ledger" on public.crimblox_economy_ledger for select to authenticated using(actor_id=auth.uid() or recipient_id=auth.uid());
drop policy if exists "read own purchases" on public.crimblox_purchases;
create policy "read own purchases" on public.crimblox_purchases for select to authenticated using(buyer_id=auth.uid());
drop policy if exists "read own notifications" on public.crimblox_notifications;
create policy "read own notifications" on public.crimblox_notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists "mark own notifications read" on public.crimblox_notifications;
create policy "mark own notifications read" on public.crimblox_notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

drop policy if exists "read public game sessions" on public.crimblox_game_sessions;
create policy "read public game sessions" on public.crimblox_game_sessions for select to authenticated using(status<>'closed');
drop policy if exists "create game sessions" on public.crimblox_game_sessions;
create policy "create game sessions" on public.crimblox_game_sessions for insert to authenticated with check(host_id=auth.uid());
drop policy if exists "host update sessions" on public.crimblox_game_sessions;
create policy "host update sessions" on public.crimblox_game_sessions for update to authenticated using(host_id=auth.uid()) with check(host_id=auth.uid());
drop policy if exists "read session members" on public.crimblox_game_session_members;
create policy "read session members" on public.crimblox_game_session_members for select to authenticated using(true);
drop policy if exists "join own session" on public.crimblox_game_session_members;
create policy "join own session" on public.crimblox_game_session_members for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "leave own session" on public.crimblox_game_session_members;
create policy "leave own session" on public.crimblox_game_session_members for delete to authenticated using(user_id=auth.uid());

grant select,insert,update,delete on public.crimblox_experiences to authenticated;
grant select,insert,delete on public.crimblox_experience_versions to authenticated;
grant select,insert,update,delete on public.crimblox_experience_votes to authenticated;
grant select,insert,update,delete on public.crimblox_asset_votes to authenticated;
grant select,insert,delete on public.crimblox_asset_comments to authenticated;
grant select,insert,delete on public.crimblox_follows to authenticated;
grant select,insert on public.crimblox_wallets to authenticated;
grant select,insert,update,delete on public.crimblox_creator_products to authenticated;
grant select on public.crimblox_economy_ledger to authenticated;
grant select on public.crimblox_purchases to authenticated;
grant select,update on public.crimblox_notifications to authenticated;
grant select,insert,update on public.crimblox_game_sessions to authenticated;
grant select,insert,delete on public.crimblox_game_session_members to authenticated;

-- Only trusted server-side code may execute financial transactions; never expose ledger writes to browser clients.
revoke insert,update,delete on public.crimblox_economy_ledger from anon,authenticated;
revoke insert,update,delete on public.crimblox_purchases from anon,authenticated;
