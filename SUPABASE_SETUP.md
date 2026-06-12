# Supabase Integration Runbook (Coolify + iOS)

This app now supports Supabase Auth directly using only two runtime keys:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If those keys are empty, the app falls back to local dev auth.

## 1) Coolify deployment choice

Use the **full `Supabase` stack** in Coolify, not only `Postgres with Supabase`.

Reason:
- `Postgres with Supabase` gives you DB only.
- Full `Supabase` gives Auth (`/auth/v1`), REST (`/rest/v1`), Realtime, Storage, Studio.

## 2) Cloudflare DNS + HTTPS

1. In Cloudflare DNS, create record:
   - Type: `A`
   - Name: `supabase`
   - Value: your server IP (for example `76.13.124.154`)
2. In Coolify, open Supabase stack service `kong` (or API gateway) and add domain:
   - `supabase.yourdomain.com`
3. Enable SSL/TLS certificate generation in Coolify for that domain.
4. In Cloudflare SSL/TLS mode, set `Full (strict)`.

## 3) iOS app configuration

In `project.yml` set these values under target `Medhavn` build settings:

- `INFOPLIST_KEY_SUPABASE_URL`
- `INFOPLIST_KEY_SUPABASE_ANON_KEY`

Example:

```yaml
INFOPLIST_KEY_SUPABASE_URL: "https://supabase.example.com"
INFOPLIST_KEY_SUPABASE_ANON_KEY: "eyJhbGciOi..."
```

Then regenerate/build project as usual.

## 4) Database schema for current app models

You can apply the checked-in SQL files directly:

- `supabase/sql/001_schema.sql` (legacy schema in public schema)
- `supabase/sql/002_rls_policies.sql` (RLS policies for legacy schema)
- `supabase/sql/003_medhavn_schema.sql` (new medhavn schema with all tables)
- `supabase/sql/004_medhavn_rls_policies.sql` (RLS policies for medhavn schema)

Run in Supabase SQL editor:

```sql
create table if not exists medication_plans (
  id uuid primary key,
  user_id uuid not null,
  created_at timestamptz not null,
  source text not null,
  source_text text not null,
  parsed_json text not null,
  patient_directions text not null,
  rationale text not null,
  needs_confirmation boolean not null default false
);

create table if not exists dose_logs (
  id uuid primary key,
  user_id uuid not null,
  plan_id uuid not null,
  timestamp timestamptz not null,
  dose double precision not null,
  units text not null,
  is_prn boolean not null default false
);

create table if not exists user_settings (
  user_id uuid primary key,
  cloud_consent boolean not null default false,
  disclaimer_accepted boolean not null default false,
  privacy_policy_accepted boolean not null default false,
  processing_consent_accepted boolean not null default false,
  consent_checklist_completed boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  educational_only_ack boolean not null,
  confirm_clinician_ack boolean not null,
  privacy_policy_ack boolean not null,
  processing_consent_ack boolean not null,
  policy_version text not null,
  accepted_at timestamptz not null default now()
);
```

## 5) Enable RLS + policies

```sql
alter table medication_plans enable row level security;
alter table dose_logs enable row level security;
alter table user_settings enable row level security;
alter table user_consents enable row level security;

create policy "plans own rows"
  on medication_plans
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "dose logs own rows"
  on dose_logs
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "settings own row"
  on user_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "consents own rows"
  on user_consents
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

## 6) Auth settings for smoother first test

In Supabase Auth settings:
- Turn **email confirmation OFF** for local testing if you want immediate session after signup.
- Keep it ON in production and verify email before login.

## 7) Quick verification checklist

1. Launch app with `SUPABASE_URL` and `SUPABASE_ANON_KEY` configured.
2. Create account in app.
3. Login in app.
4. Open Settings and confirm account fields are populated.

If signup returns account-created-but-no-session, it usually means email confirmation is enabled.

## 8) Drug Lookup Edge Function (OpenFDA proxy)

To keep the OpenFDA key off the iOS client, use the Supabase function:

- `supabase/functions/drug-lookup/index.ts`

Set the key as a Supabase secret:

```bash
supabase secrets set OPENFDA_API_KEY="your-openfda-key"
```

Deploy the function:

```bash
supabase functions deploy drug-lookup --no-verify-jwt
```

Call shape used by the app:

```text
GET {SUPABASE_URL}/functions/v1/drug-lookup?q=ibup&limit=12
```

Expected response:

```json
{"suggestions":["Ibuprofen","Ibuprofen PM", "..."]}
```
