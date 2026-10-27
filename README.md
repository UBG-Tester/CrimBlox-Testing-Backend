# CrimBlox Development Platform

CrimBlox's browser-based development platform and Supabase backend foundation. The static client is published through GitHub Pages; the Node.js API and shared CAGE game runtime require a separate server deployment.

- Live platform: https://ubg-tester.github.io/CrimBlox-Testing-Backend/platform/
- QA test lab: https://ubg-tester.github.io/CrimBlox-Testing-Backend/testing/
- GitHub Pages landing: https://ubg-tester.github.io/CrimBlox-Testing-Backend/

## Current application modules

- Supabase Auth email/password sign-up and sign-in with CrimBlox profiles
- Persistent DevForum topics, categories, search, likes/dislikes, and emoji reactions
- Private Creator Marketplace uploads for models, textures, images, video, audio, scripts, and plugins; metadata search and licensed download links
- Experience publishing with versioned project package uploads and public/private visibility
- Creator product listings, CR test-currency wallets, atomic purchase RPC, creator proceeds, and a 10% platform fee
- Realtime multiplayer test-place presence and chat
- Site checks for Supabase tables, auth state, and Storage

## Important current boundaries

CrimBlox is an independent development platform; it is not a drop-in replacement for another platform. Imported place and model files are stored as versioned assets but are not automatically executed. The existing CAGE renderer must be integrated from its actual source; it is not recreated in this repository. The game server/runtime, server-authoritative physics and replication, scripting sandbox, full Studio editor, asset moderation/transcoding/CDN, notifications UI, cash payments and withdrawals, and external platform account integration are not complete. CR is an internal test currency and is not cash or another platform's currency. Wallets start at zero; no real-money provider or top-up mechanism is configured.

## Supabase project

- Project dashboard: https://supabase.com/dashboard/project/wsvyyussvzqolozstatl
- Project API URL: https://wsvyyussvzqolozstatl.supabase.co
- Project ref: `wsvyyussvzqolozstatl`
- State table: `public.crimblox_backend_state` (RLS enabled; service-role only)
- Keepalive marker: `public.crimblox_keepalive` (only a single non-sensitive marker row is publicly readable)
- Private object bucket: `crimblox-backend-objects`

## Database migrations

The Supabase migrations in `supabase/migrations/` create the profile, forum, reaction, asset, chat, experience/version, creator product, wallet, ledger, purchase, notification, and game-session tables. Row-level security is enabled. Creator purchases use the `crimblox_purchase_product` database function so the debit/credit transaction is atomic; clients cannot write directly to the economy ledger or change wallet balances.

## Server configuration

The trusted Node.js server requires these environment variables:

- `SUPABASE_URL=https://wsvyyussvzqolozstatl.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` = the project's service-role/secret key, stored only in the backend host's secret manager. Never put this key in GitHub files, browser code, or GitHub keepalive secrets.
- Optional: `ADMIN_USERS`, `NODE_ENV`, `PORT`

`src/supabase-env.js` is a persistence adapter for the existing `core.js` environment contract. The server must await `createSupabaseEnv()` before calling `createCore(env)`, because initial state is fetched from Supabase during adapter creation. Configure graceful shutdown to await `env.flush(core.db)`.

**Migration status:** database foundation and adapter are in place, but this is not yet a fully deployed or production-ready API. The supplied files must be integrated into the server entry point, and end-to-end tests must run against the Supabase adapter before launch. The existing core currently saves its full JSON-shaped state as one row, which is a compatibility bridge rather than a normalized, high-concurrency data model.

## Keep Supabase active

The GitHub Actions workflow `.github/workflows/keep-supabase-active.yml` queries the non-sensitive `crimblox_keepalive` marker table through the database REST API every four days and supports manual runs.

The workflow is self-configured with the project's public publishable key, so no GitHub Actions secrets are needed for this read-only ping. The publishable key is designed for client-side use; the service-role/secret key must never be placed in this workflow.

To test it, open **Actions → Keep Supabase project active → Run workflow**. This is best-effort only, not a guarantee against inactivity pausing; check run history periodically.
