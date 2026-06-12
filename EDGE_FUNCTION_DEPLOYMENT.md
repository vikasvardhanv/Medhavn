# Edge Function Deployment Guide

## Store App Logs Function

This guide covers deployment of the `store-app-logs` Deno/TypeScript Edge Function to your Supabase project.

## Prerequisites

1. **Supabase Project**: Existing project with medhavn schema created
2. **Supabase CLI**: Installed and authenticated
   ```bash
   npm install -g supabase
   supabase login
   ```
3. **Database Setup**: Run migration files:
   - `supabase/sql/003_medhavn_schema.sql` (app_logs table)
   - `supabase/sql/004_medhavn_rls_policies.sql` (RLS policies)

## File Location

```
supabase/functions/store-app-logs/index.ts
```

## Deployment Steps

### 1. Verify Function File Exists
```bash
ls -la supabase/functions/store-app-logs/index.ts
```

### 2. Deploy Function
```bash
supabase functions deploy store-app-logs
```

**Expected Output:**
```
Deploying function 'store-app-logs'...
✓ Function deployed
Function URL: https://your-project-id.supabase.co/functions/v1/store-app-logs
```

### 3. Verify Deployment
Check Supabase Dashboard → Edge Functions → store-app-logs

### 4. Test Function (Optional)

#### Get Auth Token
```bash
# Login to your app and get token from AppState.authToken
# Or create a test user token via Supabase Dashboard
TOKEN="your-jwt-token-here"
PROJECT_URL="https://your-project-id.supabase.co"
```

#### Test Request
```bash
curl -X POST \
  "${PROJECT_URL}/functions/v1/store-app-logs" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [
      {
        "level": "info",
        "category": "network",
        "message": "Fetched data from https://example-project.supabase.co/rest/v1/users",
        "timestamp": "2024-01-01T12:00:00Z",
        "app_version": "1.0.0",
        "device_model": "iPhone14,1",
        "os_version": "17.2"
      }
    ]
  }'
```

#### Expected Response (Success)
```json
{
  "success": true,
  "logs_stored": 1
}
```

#### Expected Response (Auth Error)
```json
{
  "error": "Invalid or expired token"
}
```

## Monitoring

### Check Function Logs
```bash
# Real-time logs
supabase functions log store-app-logs --follow

# Last 100 lines
supabase functions log store-app-logs | tail -100
```

### Check Database
```bash
# Verify logs were stored
supabase db shell

-- Inside shell:
SELECT user_id, level, message, timestamp 
FROM medhavn.app_logs 
ORDER BY timestamp DESC 
LIMIT 10;
```

## Troubleshooting

### Issue: Function deployment fails
**Solution:**
- Ensure Supabase CLI is updated: `npm install -g supabase@latest`
- Check authentication: `supabase projects list`
- Verify project selected: `supabase projects select`

### Issue: 401 Unauthorized when calling function
**Solution:**
- Verify JWT token is valid and not expired
- Check Authorization header format: `Bearer <token>`
- Ensure token belongs to user in auth.users table

### Issue: 404 Not Found
**Solution:**
- Verify function deployed: `supabase functions list`
- Check function name is `store-app-logs` (lowercase, hyphenated)
- Verify URL path: `/functions/v1/store-app-logs`

### Issue: Logs not appearing in database
**Solution:**
- Check function logs: `supabase functions log store-app-logs`
- Verify user_id from token exists in auth.users
- Check RLS policy allows insert: 
  ```sql
  SELECT * FROM medhavn.app_logs LIMIT 1;
  ```
- Ensure sanitization isn't stripping valid message content

## Environment Variables

The Edge Function automatically has access to:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Secret key for service role access

These are injected by Supabase and don't need manual configuration.

## Version Information

- **Runtime**: Deno
- **Supabase SDK**: 2.54.0 (@supabase/supabase-js)
- **TypeScript Target**: ES2020
- **Node Compatibility**: Yes

## Function Code Overview

```typescript
// 1. Extract JWT token from Authorization header
const token = req.headers.get("Authorization")?.replace("Bearer ", "");

// 2. Verify token and get user
const { data: { user }, error } = await supabase.auth.getUser(token);

// 3. Sanitize log messages (defense in depth)
function sanitizeMessage(message: string): string {
  // Removes URLs, table names, UUIDs, emails, tokens, etc.
}

// 4. Insert logs with user_id from token
await supabase.from("app_logs").insert(sanitizedLogs);

// 5. Return success response
return new Response(JSON.stringify({ success: true }), { status: 200 });
```

## Client Integration

The iOS app integration via `AppLogExportService.swift`:
1. Gets Supabase URL from environment/Info.plist
2. Sanitizes logs before sending
3. POSTs to `${SUPABASE_URL}/functions/v1/store-app-logs`
4. Includes Bearer token in Authorization header
5. Handles success/error responses

## Performance Notes

- **Latency**: Typically 100-500ms depending on Supabase region
- **Payload Size**: Recommended max 1MB per request (handles ~100-1000 logs)
- **RLS Overhead**: Minimal (indexed on user_id and level)
- **Database Growth**: Consider cleanup policy for old logs

## Security Checklist

✅ JWT token verified before database access
✅ Service role key never exposed to client
✅ RLS policy enforces row-level access
✅ Logs sanitized before storage
✅ HTTPS enforced (Supabase default)
✅ CORS headers configured (Supabase default)

## Next Steps

1. **Deploy function**: `supabase functions deploy store-app-logs`
2. **Test e2e**: Upload logs from Settings in iOS app
3. **Monitor**: Watch function logs and database
4. **Feedback**: Refine sanitization patterns based on real logs

## Additional Resources

- [Supabase Functions Documentation](https://supabase.com/docs/guides/functions)
- [Deno Documentation](https://deno.land/manual)
- [Supabase Auth Reference](https://supabase.com/docs/guides/auth/getting-started)
