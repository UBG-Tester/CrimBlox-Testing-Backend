# CrimBlox Testing Backend

CrimBlox backend and Supabase infrastructure work. This repository targets **Supabase** for database, authentication, and storage. It does not deploy to Render and does not include games.

## Supabase project

- Project dashboard: https://supabase.com/dashboard/project/iimsbtpxsbomnkwxtkpp
- Project API URL: https://iimsbtpxsbomnkwxtkpp.supabase.co
- Keep secret/service-role keys out of Git. Browser/client code must only use the publishable/anon key.

## Keep the Supabase project active

The GitHub Actions workflow at `.github/workflows/keep-supabase-active.yml` calls the Supabase REST API every four days and can also be run manually.

Add these two repository Actions secrets in **Settings → Secrets and variables → Actions → New repository secret**:

- `SUPABASE_URL` = `https://iimsbtpxsbomnkwxtkpp.supabase.co`
- `SUPABASE_ANON_KEY` = the project's publishable key (safe for client-side use; never use the service-role key here)

Then open **Actions → Keep Supabase project active → Run workflow** once to test it.

**Important:** This is a best-effort keepalive, not a guarantee against pausing. GitHub scheduled workflows can be delayed or disabled by GitHub policy, and Supabase's inactivity/pausing rules can change. Check the workflow run history periodically.

## Backend integration status

The Supabase database schema and security policies have been created in the Supabase project. The existing API's core persistence/auth routes still need a complete migration to Supabase; do not treat this repository as production-ready until those routes and integration tests are completed.
