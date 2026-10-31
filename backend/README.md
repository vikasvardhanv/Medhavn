# Medhavn backend

The service sits between the iOS app and the self-hosted Supabase. It sends email, verifies signup codes, proxies drug search, stores app logs, and alerts SafeCircle contacts about missed doses.

Stack: Node 22, TypeScript, Hono.

## API

| Method and path | Auth | Purpose |
|---|---|---|
| `GET /health` | none | Liveness probe |
| `POST /v1/otp/send` `{email}` | none, rate limited | Email a 6-digit signup code |
| `POST /v1/otp/verify` `{email, code}` | none, rate limited | Check the code. Returns `{verified}` |
| `POST /v1/email/safecircle-invite` `{name, email}` | user JWT | Invite a SafeCircle contact |
| `GET /v1/referrals` | user JWT | The user's referral code, store link, and invite progress |
| `POST /v1/referrals` `{email, relationship}` | user JWT | Record an invite and email it with the store link and code |
| `POST /v1/referrals/claim` `{code?}` | user JWT | Link a new account to its inviter, by email or by code |
| `GET /v1/drugs/suggest?q=&limit=` | user JWT | Drug name suggestions from OpenFDA |
| `POST /v1/logs` `{logs:[...]}` | user JWT | Store sanitized app logs |

A user JWT is the Supabase access token of a signed-in user. The anon key is rejected.

Clients never send HTML or a From address. Templates live in `src/templates.ts`.

## Referrals and family links

- Run `supabase/sql/008_referrals.sql` before deploying this version.
- Each user gets an 8-character code, stored in `user_profiles.referral_code`.
- Every invite is a row in `referrals` (inviter, invitee email, relationship, status).
- When the invitee signs up, the app calls `/v1/referrals/claim`. The backend matches the invite by email, or by the code typed at sign-up. Status becomes `signed_up`.
- If the relationship is parent, child, spouse or sibling, the claim also adds a `family_links` row with status `pending`. A pending link gives no access to health data.

## Missed-dose alerts

A job runs every `MISSED_DOSE_JOB_INTERVAL_MIN` minutes. It follows these steps:

1. Read `med_cabinet_items` and the user timezone from `user_profiles`.
2. Find blocks that ended in the last 6 hours (morning 12:00, afternoon 17:00, evening 22:00, night 24:00).
3. Drop doses with a `taken` row in `pill_dose_statuses`.
4. Claim each remaining dose in `missed_dose_alerts`. The claim prevents duplicate emails.
5. Email every address in `safe_circle_contacts` for that user.

If no email is sent, the job releases the claim and tries again on the next pass.

The job reads `safe_circle_contacts`. The iOS app must write contacts to that table, or no alert is sent.

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `SUPABASE_URL` | yes | `https://supabasemedhavn.viktron.ai` |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | Server only. Never put it in the app. |
| `SUPABASE_JWT_SECRET` | yes | GoTrue signing secret. Verifies tokens locally. |
| `RESEND_API_KEY` | no | If set, mail goes through Resend and the `SMTP_*` variables are not needed. |
| `SMTP_HOST` | if no Resend key | For example `smtp.office365.com` |
| `SMTP_PORT` | no | Default 465 |
| `SMTP_USER` | if no Resend key | |
| `SMTP_PASS` | if no Resend key | |
| `MAIL_FROM` | yes | Must be on a domain verified with Resend, for example `info@mashtov.com` |
| `APP_STORE_URL` | no | Store link put in referral emails. Defaults to the Medhavn App Store page. |
| `OPENFDA_API_KEY` | no | Raises the OpenFDA rate limit |
| `MISSED_DOSE_JOB_ENABLED` | no | Default `true` |
| `MISSED_DOSE_JOB_INTERVAL_MIN` | no | Default 10 |
| `PORT` | no | Default 8080 |

## Deploy to Coolify

1. Apply `supabase/sql/007_backend_tables.sql` to the Supabase database.
2. Make sure PostgREST exposes the `medhavn` schema.
3. In Coolify, create a new application from the Git repository.
4. Set the base directory to `/backend`.
5. Set the build pack to Dockerfile.
6. Set the exposed port to 8080.
7. Add the environment variables from the table above.
8. Set a domain, for example `api.medhavn.viktron.ai`.
9. Set the health check path to `/health`.
10. Deploy.
11. Run `curl https://<domain>/health`. The answer must be `{"status":"ok",...}`.

Run one instance. The rate limiter keeps counters in memory.

## Develop

```bash
cd backend
npm install
npm test
npm run typecheck
devrun npm run dev
```

## Production

- API: `https://api-medhavn.mashtov.com` (Cloudflare certificates cover one subdomain level only, so do not use `api.medhavn.mashtov.com`).
- The iOS app reads the address from `BACKEND_URL` in `project.yml`.
- Mail: Microsoft 365 SMTP (`smtp.office365.com`, port 587) with `info@mashtov.com`.
- In Coolify, turn on "Is Literal" for `SMTP_PASS`. Without it, Coolify expands any `$` in the password.

## Rotate secrets

The old Deno function `send-email` stored an SMTP password in plain text. The function is deleted, but the password remains in git history. Change that password at the provider.
