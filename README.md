# CrimBlox Testing Backend

CrimBlox platform API and Supabase persistence integration. This repository does not deploy to Render and does not include games. The supplied API core is framework-free and uses a JSON-shaped state model; the Supabase adapter preserves that model while storing the state in PostgreSQL and uploaded project/asset blobs in a private Storage bucket.

## Supabase project

- Project dashboard: https://supabase.com/dashboard/project/wsvyyussvzqolozstatl
- Project API URL: https://wsvyyussvzqolozstatl.supabase.co
- Project ref: `wsvyyussvzqolozstatl`
- State table: `public.crimblox_backend_state` (RLS enabled; service-role only)
- Keepalive marker: `public.crimblox_keepalive` (only a single non-sensitive marker row is publicly readable)
- Private object bucket: `crimblox-backend-objects`

## Server configuration

The trusted Node.js server requires these environment variables:

- `SUPABASE_URL=https://wsvyyussvzqolozstatl.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` = the project's service-role/secret key, stored only in the backend host's secret manager. Never put this key in GitHub files, browser code, or GitHub keepalive secrets.
- Optional: `ADMIN_USERS`, `NODE_ENV`, `PORT`

`src/supabase-env.js` is a persistence adapter for the existing `core.js` environment contract. The server must await `createSupabaseEnv()` before calling `createCore(env)`, because initial state is fetched from Supabase during adapter creation. Configure graceful shutdown to await `env.flush(core.db)`.

**Migration status:** database foundation and adapter are in place, but this is not yet a fully deployed or production-ready API. The supplied files must be integrated into the server entry point, and end-to-end tests must run against the Supabase adapter before launch. The existing core currently saves its full JSON-shaped state as one row, which is a compatibility bridge rather than a normalized, high-concurrency data model.

## Keep Supabase active

The GitHub Actions workflow `.github/workflows/keep-supabase-active.yml` queries the non-sensitive `crimblox_keepalive` marker table through the database REST API every four days and supports manual runs.

Configure repository secrets at **Settings → Secrets and variables → Actions → New repository secret**:

- `SUPABASE_URL` = `https://wsvyyussvzqolozstatl.supabase.co`
- `SUPABASE_ANON_KEY` = the project's publishable key (or legacy anon key). Never use the service-role key for this workflow.

Then run **Actions → Keep Supabase project active → Run workflow** to test it. This is best-effort only, not a guarantee against inactivity pausing; check run history periodically.
