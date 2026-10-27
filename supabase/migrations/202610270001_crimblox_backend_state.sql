-- CrimBlox backend persistence foundation.
-- The API server uses the service-role key server-side only. Never expose it in browser code.
create table if not exists public.crimblox_backend_state (
  id integer primary key check (id = 1),
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.crimblox_backend_state enable row level security;
revoke all on table public.crimblox_backend_state from anon, authenticated;
grant all on table public.crimblox_backend_state to service_role;

insert into public.crimblox_backend_state (id, state)
values (1, jsonb_build_object(
  'users', '[]'::jsonb, 'sessions', '[]'::jsonb, 'teams', '[]'::jsonb,
  'invites', '[]'::jsonb, 'projects', '[]'::jsonb, 'versions', '[]'::jsonb,
  'assets', '[]'::jsonb, 'assetVersions', '[]'::jsonb, 'favorites', '[]'::jsonb,
  'reviews', '[]'::jsonb, 'purchases', '[]'::jsonb, 'plugins', '[]'::jsonb,
  'releases', '[]'::jsonb, 'threads', '[]'::jsonb, 'posts', '[]'::jsonb,
  'reactions', '[]'::jsonb, 'notifications', '[]'::jsonb, 'reports', '[]'::jsonb,
  'appeals', '[]'::jsonb, 'audit', '[]'::jsonb, 'rooms', '[]'::jsonb, 'tickets', '[]'::jsonb
))
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit)
values ('crimblox-backend-objects', 'crimblox-backend-objects', false, 40000000)
on conflict (id) do update set public = false, file_size_limit = 40000000;

-- A deliberately non-sensitive marker lets the GitHub Actions keepalive make a
-- real database REST request without granting access to application state.
create table if not exists public.crimblox_keepalive (
  id integer primary key check (id = 1),
  touched_at timestamptz not null default now()
);
alter table public.crimblox_keepalive enable row level security;
revoke all on table public.crimblox_keepalive from anon, authenticated;
grant select on table public.crimblox_keepalive to anon;
drop policy if exists "public can read keepalive marker" on public.crimblox_keepalive;
create policy "public can read keepalive marker"
  on public.crimblox_keepalive for select to anon using (true);
insert into public.crimblox_keepalive (id) values (1) on conflict (id) do nothing;
