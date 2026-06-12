# Medhavn Auth Database + API Spec

This is the backend contract to support app signup/login and consent-gated access.

## 1) Recommended database
Use PostgreSQL 15+.

## 2) Core tables

### users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name TEXT,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### user_sessions
```sql
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
```

### user_consents
```sql
CREATE TABLE user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  educational_only_ack BOOLEAN NOT NULL,
  confirm_clinician_ack BOOLEAN NOT NULL,
  privacy_policy_ack BOOLEAN NOT NULL,
  processing_consent_ack BOOLEAN NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  policy_version TEXT NOT NULL
);
CREATE INDEX idx_user_consents_user_id ON user_consents(user_id);
```

## 3) Password + token rules
- Hash password with Argon2id (preferred) or bcrypt (cost >= 12).
- Never store plaintext password.
- Return short-lived JWT access token (15m) + refresh token in secure httpOnly cookie or response body.
- Rotate refresh tokens on every refresh.

## 4) API endpoints for app

### POST /auth/signup
Request:
```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!",
  "fullName": "User Name"
}
```
Success response:
```json
{
  "token": "<access-jwt>",
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  }
}
```

### POST /auth/login
Request:
```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!"
}
```
Success response:
```json
{
  "token": "<access-jwt>",
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  }
}
```

### POST /auth/logout (optional)
Invalidate current refresh session.

### GET /auth/me (optional)
Returns user profile for token validation.

## 5) Consent endpoint (recommended)
### POST /consents
Headers: Authorization Bearer access token
Request:
```json
{
  "educationalOnlyAck": true,
  "confirmClinicianAck": true,
  "privacyPolicyAck": true,
  "processingConsentAck": true,
  "policyVersion": "2026-02-27"
}
```

## 6) App integration point
The app reads backend URL from Info.plist key:
- AUTH_API_BASE_URL

Current app client expects:
- /auth/signup
- /auth/login

If AUTH_API_BASE_URL is empty, app uses local development fallback auth.

## 7) Production security checklist
- Enforce HTTPS only
- Add rate limits on auth routes
- Add IP/device anomaly checks
- Use email verification + password reset flow
- Store audit logs for auth events
- Add DB backups and monitoring
