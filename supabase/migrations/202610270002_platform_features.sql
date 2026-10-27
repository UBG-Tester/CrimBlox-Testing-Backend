create extension if not exists pgcrypto;

create table if not exists public.crimblox_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);
create table if not exists public.crimblox_forum_topics (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 140),
  category text not null default 'Help' check (category in ('Announcements','Help','Scripting','Resources','Showcase','Bug Reports')),
  body text not null check (char_length(body) between 1 and 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.crimblox_forum_reactions (
  topic_id uuid not null references public.crimblox_forum_topics(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike','❤️','😂','🔥','👍','👀','🎉')),
  created_at timestamptz not null default now(),
  primary key(topic_id,user_id)
);
create table if not exists public.crimblox_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  description text not null default '',
  asset_type text not null check (asset_type in ('Models','Textures','Images','Video','Audio','Scripts','Plugins','Other')),
  file_name text not null,
  storage_path text not null unique,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes >= 0),
  created_at timestamptz not null default now()
);
create table if not exists public.crimblox_chat_rooms (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.crimblox_chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.crimblox_chat_rooms(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
insert into public.crimblox_chat_rooms(slug,name) values ('test-place','Test Place Lobby') on conflict(slug) do nothing;

alter table public.crimblox_profiles enable row level security;
alter table public.crimblox_forum_topics enable row level security;
alter table public.crimblox_forum_reactions enable row level security;
alter table public.crimblox_assets enable row level security;
alter table public.crimblox_chat_rooms enable row level security;
alter table public.crimblox_chat_messages enable row level security;

drop policy if exists "profiles are readable" on public.crimblox_profiles;
create policy "profiles are readable" on public.crimblox_profiles for select to authenticated using (true);
drop policy if exists "users create own profile" on public.crimblox_profiles;
create policy "users create own profile" on public.crimblox_profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "users update own profile" on public.crimblox_profiles;
create policy "users update own profile" on public.crimblox_profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "authenticated users read topics" on public.crimblox_forum_topics;
create policy "authenticated users read topics" on public.crimblox_forum_topics for select to authenticated using (true);
drop policy if exists "users create own topics" on public.crimblox_forum_topics;
create policy "users create own topics" on public.crimblox_forum_topics for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "authors update own topics" on public.crimblox_forum_topics;
create policy "authors update own topics" on public.crimblox_forum_topics for update to authenticated using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists "authors delete own topics" on public.crimblox_forum_topics;
create policy "authors delete own topics" on public.crimblox_forum_topics for delete to authenticated using (auth.uid() = author_id);

drop policy if exists "read forum reactions" on public.crimblox_forum_reactions;
create policy "read forum reactions" on public.crimblox_forum_reactions for select to authenticated using (true);
drop policy if exists "users set own reactions" on public.crimblox_forum_reactions;
create policy "users set own reactions" on public.crimblox_forum_reactions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "users change own reactions" on public.crimblox_forum_reactions;
create policy "users change own reactions" on public.crimblox_forum_reactions for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users remove own reactions" on public.crimblox_forum_reactions;
create policy "users remove own reactions" on public.crimblox_forum_reactions for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "read asset metadata" on public.crimblox_assets;
create policy "read asset metadata" on public.crimblox_assets for select to authenticated using (true);
drop policy if exists "users upload own asset metadata" on public.crimblox_assets;
create policy "users upload own asset metadata" on public.crimblox_assets for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists "owners update asset metadata" on public.crimblox_assets;
create policy "owners update asset metadata" on public.crimblox_assets for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists "owners delete asset metadata" on public.crimblox_assets;
create policy "owners delete asset metadata" on public.crimblox_assets for delete to authenticated using (auth.uid() = owner_id);

drop policy if exists "authenticated read chat rooms" on public.crimblox_chat_rooms;
create policy "authenticated read chat rooms" on public.crimblox_chat_rooms for select to authenticated using (true);
drop policy if exists "authenticated read chat messages" on public.crimblox_chat_messages;
create policy "authenticated read chat messages" on public.crimblox_chat_messages for select to authenticated using (true);
drop policy if exists "authenticated send chat messages" on public.crimblox_chat_messages;
create policy "authenticated send chat messages" on public.crimblox_chat_messages for insert to authenticated with check (auth.uid() = author_id);

-- Private uploads: users may only access objects under their own auth UID prefix.
drop policy if exists "users upload own assets" on storage.objects;
create policy "users upload own assets" on storage.objects for insert to authenticated with check (bucket_id = 'crimblox-backend-objects' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "users read own assets" on storage.objects;
create policy "users read own assets" on storage.objects for select to authenticated using (bucket_id = 'crimblox-backend-objects' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "users update own assets" on storage.objects;
create policy "users update own assets" on storage.objects for update to authenticated using (bucket_id = 'crimblox-backend-objects' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'crimblox-backend-objects' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "users delete own assets" on storage.objects;
create policy "users delete own assets" on storage.objects for delete to authenticated using (bucket_id = 'crimblox-backend-objects' and (storage.foldername(name))[1] = auth.uid()::text);

grant select, insert, update, delete on public.crimblox_profiles to authenticated;
grant select, insert, update, delete on public.crimblox_forum_topics to authenticated;
grant select, insert, update, delete on public.crimblox_forum_reactions to authenticated;
grant select, insert, update, delete on public.crimblox_assets to authenticated;
grant select on public.crimblox_chat_rooms to authenticated;
grant select, insert on public.crimblox_chat_messages to authenticated;

-- Explicit profile foreign keys let PostgREST embed usernames with forum/assets/chat rows.
do $$ begin
  if not exists (select 1 from pg_constraint where conname='crimblox_topics_profile_fk') then
    alter table public.crimblox_forum_topics add constraint crimblox_topics_profile_fk foreign key (author_id) references public.crimblox_profiles(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname='crimblox_assets_profile_fk') then
    alter table public.crimblox_assets add constraint crimblox_assets_profile_fk foreign key (owner_id) references public.crimblox_profiles(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname='crimblox_messages_profile_fk') then
    alter table public.crimblox_chat_messages add constraint crimblox_messages_profile_fk foreign key (author_id) references public.crimblox_profiles(id) on delete cascade;
  end if;
end $$;

-- Enable live inserts for the test-place chat feed.
do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='crimblox_chat_messages'
  ) then
    alter publication supabase_realtime add table public.crimblox_chat_messages;
  end if;
end $$;
